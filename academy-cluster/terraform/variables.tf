variable "name" {
  description = "Name of the cluster, from the Resource slug. AWS names are academy-<name>-..."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{0,30}[a-z0-9]$", var.name))
    error_message = "name: 2 to 32 lowercase letters, digits or hyphens, starting and ending with a letter or digit."
  }
}

variable "region" {
  description = "AWS region of the cluster."
  type        = string
}

variable "instance_type" {
  description = "Machine size. t3.medium is 2 vCPU and 4 GB, enough for K3s and a few small apps."
  type        = string
  default     = "t3.medium"

  validation {
    condition     = contains(["t3.medium", "t3.large", "t3a.medium", "t3a.large"], var.instance_type)
    error_message = "instance_type: one of t3.medium, t3.large, t3a.medium, t3a.large."
  }
}

variable "permissions_boundary_arn" {
  description = "Permissions boundary set on the machine's role, when the role that runs Terraform requires one (C2)."
  type        = string
  default     = null
}

variable "k3s_version" {
  description = "K3s release installed on the machine."
  type        = string
  default     = "v1.37.2+k3s1"
}

variable "k3s_install_sha256" {
  description = "SHA-256 of the K3s install.sh of k3s_version; the machine refuses an installer that does not match."
  type        = string
  default     = "ed01f89fd977bf20ac1516bbebf8370bf3ddbaa55dac8aba610956a4c78cc00b"
}

variable "welcome_image" {
  description = "Image of the default page the cluster shows until an app is deployed."
  type        = string
  default     = "nginxinc/nginx-unprivileged:1.31-alpine@sha256:b5047b9b76845eac124358373c6852377c52e4b05834a47647e955dd91cb8f1e"
}
