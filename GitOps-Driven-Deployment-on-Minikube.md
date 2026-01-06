# GitOps-Driven Deployment on Minikube

## Overview
This project demonstrates a production-grade workflow combining Infrastructure as Code (Terraform) and GitOps (ArgoCD). Terraform generates Kubernetes manifest files, which are then automatically deployed by ArgoCD.

## Architecture
**Terraform** → Generates YAML Manifests → **Git** → **ArgoCD** → Deploys to **Minikube**

See `architecture-diagram.png` for detailed system architecture.

## Prerequisites
- macOS with Docker Desktop installed
- Minikube
- kubectl
- Terraform
- ArgoCD CLI
- Git

## Project Structure
```
minikube-argocd-lab/
├── app/
│   ├── main.py                # Python FastAPI application
│   ├── Dockerfile             # Non-root container image
│   └── requirements.txt       # Python dependencies
├── terraform/
│   ├── main.tf                # Terraform configuration
│   ├── variables.tf           # Variable definitions
│   ├── outputs.tf             # Output definitions
│   └── templates/             # YAML templates
│       ├── namespace.yaml.tpl
│       ├── tls-secret.yaml.tpl
│       ├── deployment.yaml.tpl
│       ├── service.yaml.tpl
│       └── ingress.yaml.tpl
├── k8s/                       # Generated manifests (managed by ArgoCD)
│   ├── namespace.yaml
│   ├── tls-secret.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   └── ingress.yaml
├── argocd/
│   └── application.yaml       # ArgoCD Application definition
├── architecture-diagram.png
└── README.md
```

## Technology Stack
- **Minikube**: Local Kubernetes cluster with Docker driver
- **Terraform**: Generates Kubernetes manifest files
- **ArgoCD**: GitOps continuous delivery
- **Python 3.10 + FastAPI**: REST API application
- **Uvicorn**: ASGI server
- **Docker**: Container runtime
- **Nginx Ingress**: Traffic management and TLS termination

## Workflow

### How It Works
1. **Terraform** generates Kubernetes YAML manifests from templates
2. Developer commits generated manifests to **Git**
3. **ArgoCD** monitors the Git repository
4. **ArgoCD** automatically deploys changes to Minikube

This combines:
- **IaC**: Infrastructure defined in Terraform
- **GitOps**: Declarative deployment via ArgoCD

## Setup Instructions

### 1. Initialize Minikube Cluster
```bash
# Start Minikube with Docker driver
minikube start --driver=docker --cpus=4 --memory=8192

# Enable ingress addon
minikube addons enable ingress

# Verify cluster is running
kubectl cluster-info
```

### 2. Install ArgoCD
```bash
# Create ArgoCD namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo

# Port forward to access ArgoCD UI (in separate terminal)
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Access ArgoCD at: https://localhost:8080
- Username: `admin`
- Password: (from command above)

### 3. Build Application Image

**Important:** Use version tags (not `:latest`) to enable proper GitOps workflow.

```bash
# Navigate to app directory
cd app

# Point to Minikube's Docker daemon
eval $(minikube docker-env)

# Build with version tag (increment for each new version)
docker build -t web-api:v1.0 .

# Verify image was created
docker images | grep web-api
```

**Note:** Each time you make changes, increment the version (v1.0 → v1.1 → v2.0, etc.). This allows ArgoCD to detect changes when the deployment manifest is updated.

### 4. Generate Manifests with Terraform

```bash
# Navigate to terraform directory
cd ../terraform

# Initialize Terraform (first time only)
terraform init

# Review what will be generated
terraform plan

# Generate the manifest files
terraform apply

# When prompted, type 'yes' to confirm
```

This creates YAML files in the `k8s/` directory with your specified image version:
- `namespace.yaml`
- `tls-secret.yaml` (with auto-generated certificate)
- `deployment.yaml` (with image: web-api:v1.0)
- `service.yaml`
- `ingress.yaml`

### 5. Commit Generated Manifests to Git
```bash
cd ..
git add k8s/
git commit -m "Generate Kubernetes manifests with Terraform"
git push
```

### 6. Deploy with ArgoCD
```bash
# Apply ArgoCD Application
kubectl apply -f argocd/application.yaml

# Watch ArgoCD sync (in separate terminal or ArgoCD UI)
kubectl get application web-api -n argocd -w

# Or use ArgoCD CLI
argocd app get web-api --port-forward --port-forward-namespace argocd
```

### 7. Configure Local DNS
```bash
echo "127.0.0.1 web.local" | sudo tee -a /etc/hosts
```

### 8. Start Minikube Tunnel
In a **separate terminal**, run:
```bash
minikube tunnel
# Keep this running
```

### 9. Access the Application
```bash
# Test HTTP to HTTPS redirect
curl -v http://web.local 2>&1 | grep -i location

# Test HTTPS endpoints
curl -k https://web.local/
curl -k https://web.local/health
```

## Application Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/` | GET | Welcome message with version |
| `/health` | GET | Health check endpoint |

## Security Features

### Non-Root Container
The application runs as user `appuser` (UID 1000):
```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 1000
```

Verify:
```bash
kubectl exec -it $(kubectl get pod -l app=web-api -n web-api -o jsonpath='{.items[0].metadata.name}') -n web-api -- id
# Output: uid=1000(appuser) gid=1000(appuser)
```

### TLS/HTTPS
- All HTTP traffic (port 80) is redirected to HTTPS (port 443)
- TLS termination at ingress level
- Self-signed certificate auto-generated by Terraform

## Making Changes

### Update Infrastructure (Terraform)
```bash
# 1. Modify Terraform variables or templates
cd terraform

# 2. Regenerate manifests
terraform apply

# 3. Commit changes to Git
cd ..
git add k8s/
git commit -m "Update infrastructure configuration"
git push

# 4. ArgoCD will automatically detect and sync changes
```

### Update Application Code
```bash
# 1. Modify code in app/main.py

# 2. Rebuild image
cd app
eval $(minikube docker-env)
# Build with version tag (increment for each new version)
docker build -t web-api:v2.0 .

# 3. Restart deployment
kubectl rollout restart deployment/web-api -n web-api

# Or let ArgoCD handle it if you update the image tag
```


## Cleanup

```bash
# Delete ArgoCD application
kubectl delete -f argocd/application.yaml

# Delete namespace
kubectl delete namespace web-api

# Delete ArgoCD
kubectl delete namespace argocd

# Clean up Terraform state
cd terraform
terraform destroy

# Stop Minikube
minikube stop

# (Optional) Delete cluster
minikube delete
```

## Project Highlights

✅ **Infrastructure as Code**: Terraform generates all Kubernetes manifests  
✅ **GitOps**: ArgoCD provides declarative continuous delivery  
✅ **Security**: Non-root containers, TLS encryption, HTTPS redirect  
✅ **Automation**: Changes auto-deployed via ArgoCD  
✅ **Production-Ready**: Health checks, resource limits, replicas  
✅ **Best Practices**: Combines IaC and GitOps methodologies  

## Workflow Summary

```
Developer
   ↓
Terraform (generates YAML)
   ↓
Git Repository (k8s/*.yaml)
   ↓
ArgoCD (monitors & deploys)
   ↓
Minikube Cluster
```
