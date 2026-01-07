variable "namespace" {
  description = "Kubernetes namespace for the application"
  type        = string
  default     = "web-api"
}

variable "replicas" {
  description = "Number of replicas for the deployment"
  type        = number
  default     = 2
}

variable "image_name" {
  description = "Docker image name and tag for the web API"
  type        = string
  default     = "evgenys46/cibus-demo-api:latest"
}

variable "ingress_host" {
  description = "Hostname for ingress"
  type        = string
  default     = "web.local"
}

variable "service_name" {
  description = "Name of the Kubernetes service"
  type        = string
  default     = "web-api-service"
}

variable "app_name" {
  description = "Application name used for labels and resource names"
  type        = string
  default     = "web-api"
}
