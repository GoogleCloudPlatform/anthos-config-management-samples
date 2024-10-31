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

// Constants for Config Sync annotation names. This annotation is added to
// RootSync or RepoSync resources to hold the URL of the image to sync. By
// comparing the old and new values in the admission review request, we can
// detect if a new image has been introduced, triggering an image verification.
const (
	imageToSyncAnnotation = "configsync.gke.io/image-to-sync"
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

// validateImage verifies the image using Cosign CLI and the public key in the
// cosign-key secret.
func verifyImageSignature(image string) error {
	if image == "" {
		return nil
	}
	cmd := exec.Command("cosign", "verify", image, "--key", "/cosign-key/cosign.pub")
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("cosign verification failed for image %s: %s, output: %s", image, err, string(output))
	}
	return nil
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
		return fmt.Errorf("gcloud authenticate to image registry %s failed: %s, output: %s", registry, err, string(output))
	}
	klog.Infof("result: %s, authorization done", string(output))
	authorized = true
	return nil
}

// getAnnotationByKey extracts a specific annotation by key from the raw JSON data.
func getAnnotationByKey(raw []byte, key string) (string, error) {
	var metadata map[string]interface{}
	if err := json.Unmarshal(raw, &metadata); err != nil {
		return "", err
	}

	annotations, ok := metadata["metadata"].(map[string]interface{})["annotations"].(map[string]interface{})
	if !ok {
		klog.Infof("No annotations found in the object")
		return "", nil
	}

	if value, found := annotations[key]; found {
		return fmt.Sprintf("%v", value), nil
	}

	return "", nil
}

// handleWebhook is the main function that handles the admission control webhook requests.
// It reads the request body, extracts the old and new annotations, and compares them to
// determine if the image URL has changed. If a change is detected, it
// validates the new image with given url.
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

	if err := authenticateToImageRegistry(); err != nil {
		klog.Errorf("Failed to authenticate Cosign to the source image registry: %v", err)
		http.Error(w, "Failed to authenticate Cosign to the source image registry: %v", http.StatusInternalServerError)
	}

	response := &admissionv1.AdmissionResponse{
		UID: admissionReview.Request.UID,
	}

	oldImage, err := getAnnotationByKey(admissionReview.Request.OldObject.Raw, imageToSyncAnnotation)
	if err != nil {
		klog.Errorf("Failed to extract old annotations: %v", err)
		response.Result = &metav1.Status{
			Message: fmt.Sprintf("Failed to extract old annotations: %v", err),
		}
		response.Allowed = false
		return
	}

	newImage, err := getAnnotationByKey(admissionReview.Request.Object.Raw, imageToSyncAnnotation)
	if err != nil {
		klog.Errorf("Failed to extract new annotations: %v", err)
		response.Result = &metav1.Status{
			Message: fmt.Sprintf("Failed to extract new annotations: %v", err),
		}
		response.Allowed = false
		return
	}

	if newImage != oldImage {
		klog.Infof("Annotation %s changed from %s to %s", imageToSyncAnnotation, oldImage, newImage)
		if err := verifyImageSignature(newImage); err != nil {
			klog.Errorf("Image verification failed: %v", err)
			response.Allowed = false
			response.Result = &metav1.Status{
				Message: fmt.Sprintf("Image verification failed: %v", err),
			}
		} else {
			klog.Infof("Image verification successful for %s", newImage)
			response.Allowed = true
		}
	} else {
		response.Allowed = true
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
