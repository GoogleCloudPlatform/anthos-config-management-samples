package main

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"os/exec"
	"strings"
	"sync"

	admissionv1 "k8s.io/api/admission/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

const (
	SourceURL    = "configsync.gke.io/source-url"
	SourceCommit = "configsync.gke.io/source-commit"
)

var authorized bool
var authMutex sync.Mutex // Add a mutex for thread safety

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
	log.Printf("command %s, url: %s, digest: %s", cmd.String(), image, commit)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("cosign verification failed: %s, output: %s", err, string(output))
	}
	return nil
}

// replaceTagWithDigest replaces the tag in an image URL with the given digest SHA.
func replaceTagWithDigest(imageURL, commitSHA string) (string, error) {
	if !strings.Contains(imageURL, ":") {
		return "", fmt.Errorf("invalid image URL format: no tag or digest found")
	}
	imageWithoutTag := strings.Split(imageURL, ":")[0]

	// image URL has digeset
	if strings.Contains(imageURL, "@sha256:") {
		URLWithSha := fmt.Sprintf("%s:%s", imageWithoutTag, commitSHA)
		log.Printf("Replaced existing digest with new digest: %s", URLWithSha)
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
		log.Printf("skip authorizing docker")
		return nil
	}
	gcloudCmd := exec.Command("gcloud", "auth", "print-access-token")
	accessTokenBytes, err := gcloudCmd.Output()
	if err != nil {
		return fmt.Errorf("Error fetching access token: %v\n", err)
	}
	// Convert the output to a string and trim any trailing newline
	accessToken := string(accessTokenBytes)
	accessToken = accessToken[:len(accessToken)-1] // Remove the trailing newline

	cmd := exec.Command("cosign", "login", "us-central1-docker.pkg.dev", "-u", "oauth2accesstoken", "-p", accessToken)
	log.Printf("command %s", cmd.String())
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("gcloud auth ar failed: %s, output: %s", err, string(output))
	}
	log.Printf("result: %s, authorization done", string(output))
	authorized = true
	return nil
}

func handleWebhook(w http.ResponseWriter, r *http.Request) {

	// Read the body
	body, err := ioutil.ReadAll(r.Body)
	if err != nil {
		log.Printf("Failed to read request body: %v", err)
		http.Error(w, "Failed to read request body", http.StatusBadRequest)
		return
	}

	var admissionReview admissionv1.AdmissionReview
	if err := json.Unmarshal(body, &admissionReview); err != nil {
		log.Printf("Failed to unmarshal admission review: %v", err)
		http.Error(w, "Failed to unmarshal admission review", http.StatusBadRequest)
		return
	}

	// Extract old and new annotations
	oldAnnotations, err := getAnnotations(admissionReview.Request.OldObject.Raw)
	if err != nil {
		log.Printf("Failed to extract old annotations: %v", err)
	}

	newAnnotations, err := getAnnotations(admissionReview.Request.Object.Raw)
	if err != nil {
		log.Printf("Failed to extract new annotations: %v", err)
	}

	// Log old and new annotations for comparison
	log.Printf("Old Annotations: %v", oldAnnotations)
	log.Printf("New Annotations: %v", newAnnotations)

	// Send the admission response
	response := &admissionv1.AdmissionResponse{
		UID: admissionReview.Request.UID,
	}

	// Compare the annotations and check for changes
	if newAnnotations[SourceURL] != oldAnnotations[SourceURL] ||
		newAnnotations[SourceCommit] != oldAnnotations[SourceCommit] {
		log.Printf("Detected annotation changes")
		auth()
		// Validate image using cosign
		if err := validateImage(newAnnotations[SourceURL], newAnnotations[SourceCommit]); err != nil {
			log.Printf("Image validation failed: %v", err)
			response.Allowed = false
			response.Result = &metav1.Status{
				Message: fmt.Sprintf("Image validation failed: %v", err),
			}
		} else {
			log.Printf("Image validation successful for %s", newAnnotations[SourceURL])
			response.Allowed = true
		}
	} else {
		log.Printf("No annotation changes detected")
	}

	admissionReview.Response = response
	if err := json.NewEncoder(w).Encode(admissionReview); err != nil {
		log.Printf("Failed to encode admission response: %v", err)
	}
}

func main() {
	http.HandleFunc("/validate", handleWebhook)
	log.Println("Starting webhook server on port 8443...")
	log.Fatal(http.ListenAndServeTLS(":8443", "/tls/tls.crt", "/tls/tls.key", nil))
}
