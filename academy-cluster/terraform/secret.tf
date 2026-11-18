# The kubeconfig of the `academy` namespace. Created empty: the machine writes its value at first
# boot, so the kubeconfig never goes through Terraform or its state. No recovery window, so
# removing the cluster leaves nothing behind.
resource "aws_secretsmanager_secret" "kubeconfig" {
  name                    = "academy-${var.name}-kubeconfig"
  description             = "Kubeconfig of the academy namespace of the Academy cluster ${var.name}, written by the machine"
  recovery_window_in_days = 0
}

# The machine's role may write that one secret, and nothing else. It cannot read it back.
data "aws_iam_policy_document" "node_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "node" {
  statement {
    actions   = ["secretsmanager:PutSecretValue"]
    resources = [aws_secretsmanager_secret.kubeconfig.arn]
  }
}

resource "aws_iam_role" "node" {
  name                 = "academy-${var.name}-node"
  assume_role_policy   = data.aws_iam_policy_document.node_assume.json
  permissions_boundary = var.permissions_boundary_arn
}

resource "aws_iam_role_policy" "node" {
  name   = "write-kubeconfig"
  role   = aws_iam_role.node.id
  policy = data.aws_iam_policy_document.node.json
}

resource "aws_iam_instance_profile" "node" {
  name = "academy-${var.name}-node"
  role = aws_iam_role.node.name
}
