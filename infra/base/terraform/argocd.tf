
#---------------------------------------------------------------
# ArgoCD Installation via Terraform
#---------------------------------------------------------------
resource "helm_release" "argocd" {
  count = var.enable_argocd ? 1 : 0
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "8.1.1"
  namespace        = "argocd"
  create_namespace = true

  values = [
    <<-EOT
    configs:
      cm:
        kustomize.buildOptions: --enable-helm
        application.resourceTrackingMethod: annotation

    dex:
      enabled: false

    notifications:
      enabled: false

    EOT
  ]

  depends_on = [module.eks.cluster_id, module.karpenter, aws_eks_addon.aws_ebs_csi_driver]
}
