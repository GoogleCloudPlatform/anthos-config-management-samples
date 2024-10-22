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

const (
	SourceURL    = "configsync.gke.io/source-url"
	SourceCommit = "configsync.gke.io/source-commit"
)

var (
	registryToken string
	registry      string
	tokenFile     string
	authorized    bool
	authMutex     sync.Mutex // Add a mutex for thread safety
)

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

// Function to extract annotations from JSON
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

func auth() error {
	authMutex.Lock()         // Acquire the lock before accessing shared resources
	defer authMutex.Unlock() // Release the lock when the function exits

	if authorized {
		return nil
	}

	cmd := exec.Command("cosign", "login", registry, "-u", "oauth2accesstoken", "-p", registryToken)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("gcloud auth ar failed: %s, output: %s", err, string(output))
	}
	klog.Infof("result: %s, authorization done", string(output))
	authorized = true
	return nil
}

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

	// Extract old and new annotations
	oldAnnotations, err := getAnnotations(admissionReview.Request.OldObject.Raw)
	if err != nil {
		klog.Errorf("Failed to extract old annotations: %v", err)
	}

	newAnnotations, err := getAnnotations(admissionReview.Request.Object.Raw)
	if err != nil {
		klog.Errorf("Failed to extract new annotations: %v", err)
	}

	// Send the admission response
	response := &admissionv1.AdmissionResponse{
		UID: admissionReview.Request.UID,
	}

	// Compare the annotations and check for changes
	if newAnnotations[SourceURL] != oldAnnotations[SourceURL] ||
		newAnnotations[SourceCommit] != oldAnnotations[SourceCommit] {
		klog.Info("Detected annotation changes")
		if err := auth(); err != nil {
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
