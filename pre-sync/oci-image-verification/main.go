package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"strings"
	"sync"

	admissionv1 "k8s.io/api/admission/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/klog/v2"
)

// Constants for Config Sync annotations. These annotations are added to the
// RootSync or RepoSync resources for the image URL and digest SHA. They are used to
// validate the image during admission control.
const (
	SourceURL    = "configsync.gke.io/source-url"
	SourceCommit = "configsync.gke.io/source-commit"
)

// Global variables for configuration and state
var (
	registryToken string
	registry      string
	tokenFile     string
	authorized    bool
	authMutex     sync.Mutex // Add a mutex for thread safety
)

// init initializes the application by parsing command-line flags
// and reading the registry token from a file.
func init() {
	flag.StringVar(&registry, "registry", "us.pkg.dev", "URL of the artifact registry")
	flag.StringVar(&tokenFile, "token-file", "/var/run/secrets/token", "Path to the file containing the registry token")
	flag.Parse()

	// Read the token from the mounted secret file
	content, err := os.ReadFile(tokenFile)
	if err != nil {
		klog.Errorf("Error reading token file: %v", err)
	}
	registryToken = strings.TrimSpace(string(content))

	if registryToken == "" {
		klog.Errorf("Registry token is required. Ensure the token file is properly mounted and contains the token.")
	}
}

// getAnnotations extracts annotations from the raw JSON data in the admission review.
func getAnnotations(raw []byte) (map[string]string, error) {
	var metadata map[string]interface{}
	if err := json.Unmarshal(raw, &metadata); err != nil {
		return nil, err
	}
	if annotations, ok := metadata["metadata"].(map[string]interface{})["annotations"].(map[string]interface{}); ok {
		annotationsMap := make(map[string]string)
		for k, v := range annotations {
			annotationsMap[k] = fmt.Sprintf("%v", v)
		}
		return annotationsMap, nil
	}
	return nil, fmt.Errorf("no annotations found")
}

// validateImage verifies the image using Cosign CLI and the public key in the
// cosign-key secret.
func validateImage(image, commit string) error {
	if image == "" || commit == "" {
		return nil
	}
	imageWithDigest, err := replaceTagWithDigest(image, commit)
	if err != nil {
		return fmt.Errorf("failed to replace tag with digest: %v", err)
	}
	cmd := exec.Command("cosign", "verify", imageWithDigest, "--key", "/cosign-key/cosign.pub")
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("cosign verification failed for image %s: %s, output: %s", imageWithDigest, err, string(output))
	}
	return nil
}

// replaceTagWithDigest replaces the tag in an image URL with the given digest SHA.
func replaceTagWithDigest(imageURL, commitSHA string) (string, error) {
	if !strings.Contains(imageURL, ":") {
		return "", fmt.Errorf("invalid image URL format: no tag or digest found")
	}
	imageWithoutTag := strings.Split(imageURL, ":")[0]

	// image URL has digest
	if strings.Contains(imageURL, "@sha256:") {
		URLWithSha := fmt.Sprintf("%s:%s", imageWithoutTag, commitSHA)
		klog.Infof("Replaced existing digest with new digest: %s", URLWithSha)
		return URLWithSha, nil
	}

	// image URL has tag
	URLWithSha := fmt.Sprintf("%s@sha256:%s", imageWithoutTag, commitSHA)
	return URLWithSha, nil
}

// authenticateToImageRegistry authenticates to the image registry using the
// provided token. This is done by calling the `cosign login` command. The authentication
// method just demonstrates one way of solving this issue. User could also use
// username + password.
func authenticateToImageRegistry() error {
	authMutex.Lock()         // Acquire the lock before accessing shared resources
	defer authMutex.Unlock() // Release the lock when the function exits

	if authorized {
		return nil
	}

	cmd := exec.Command("cosign", "login", registry, "-u", "oauth2accesstoken", "-p", registryToken)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("gcloud authenticateToImageRegistry ar failed: %s, output: %s", err, string(output))
	}
	klog.Infof("result: %s, authorization done", string(output))
	authorized = true
	return nil
}

// handleWebhook is the main function that handles the admission control webhook requests.
// It reads the request body, extracts the old and new annotations, and compares them to
// determine if the image URL or digest SHA has changed. If a change is detected, it
// validates the new image with given url and digest SHA.
func handleWebhook(w http.ResponseWriter, r *http.Request) {
	body, err := io.ReadAll(r.Body)
	if err != nil {
		klog.Errorf("Failed to read request body: %v", err)
		http.Error(w, "Failed to read request body", http.StatusBadRequest)
		return
	}

	var admissionReview admissionv1.AdmissionReview
	if err := json.Unmarshal(body, &admissionReview); err != nil {
		klog.Errorf("Failed to unmarshal admission review: %v", err)
		http.Error(w, "Failed to unmarshal admission review", http.StatusBadRequest)
		return
	}

	// Extract old and new annotations from the admission review
	oldAnnotations, err := getAnnotations(admissionReview.Request.OldObject.Raw)
	if err != nil {
		klog.Errorf("Failed to extract old annotations: %v", err)
	}

	newAnnotations, err := getAnnotations(admissionReview.Request.Object.Raw)
	if err != nil {
		klog.Errorf("Failed to extract new annotations: %v", err)
	}

	response := &admissionv1.AdmissionResponse{
		UID: admissionReview.Request.UID,
	}

	// Compare the source annotations and check for changes
	if newAnnotations[SourceURL] != oldAnnotations[SourceURL] ||
		newAnnotations[SourceCommit] != oldAnnotations[SourceCommit] {
		klog.Info("Detected annotation changes")
		if err := authenticateToImageRegistry(); err != nil {
			klog.Errorf("Failed to authorize Cosign %v", err)
		}
		// Validate image using cosign
		if err := validateImage(newAnnotations[SourceURL], newAnnotations[SourceCommit]); err != nil {
			klog.Errorf("Image validation failed: %v", err)
			response.Allowed = false
			response.Result = &metav1.Status{
				Message: fmt.Sprintf("Image validation failed: %v", err),
			}
		} else {
			klog.Errorf("Image validation successful for %s", newAnnotations[SourceURL])
			response.Allowed = true
		}
	} else {
		klog.Info("No annotation changes detected")
	}

	admissionReview.Response = response
	if err := json.NewEncoder(w).Encode(admissionReview); err != nil {
		klog.Errorf("Failed to encode admission response: %v", err)
	}
}

func main() {
	http.HandleFunc("/validate", handleWebhook)
	klog.Info("Starting webhook server on port 10250...")
	klog.Error(http.ListenAndServeTLS(":10250", "/tls/tls.crt", "/tls/tls.key", nil))
}
