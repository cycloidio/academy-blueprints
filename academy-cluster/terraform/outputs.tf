output "public_ip" {
  description = "Fixed public address of the cluster."
  value       = aws_eip.node.public_ip
}

output "url" {
  description = "Default page of the cluster; it answers once the kubeconfig is in the secret."
  value       = "http://${aws_eip.node.public_ip}/"
}

output "hostname_suffix" {
  description = "Apps answer on <app>-<environment>.<this suffix> (sslip.io resolves it to the public address)."
  value       = "${aws_eip.node.public_ip}.sslip.io"
}

output "kubeconfig_secret_name" {
  description = "Secrets Manager secret holding the kubeconfig of the academy namespace."
  value       = aws_secretsmanager_secret.kubeconfig.name
}

output "region" {
  description = "AWS region of the cluster."
  value       = var.region
}
