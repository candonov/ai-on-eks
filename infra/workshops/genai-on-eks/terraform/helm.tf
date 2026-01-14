################################################################################
# Observability Stack (Kube Prometheus Stack + Grafana Operator)
################################################################################
resource "helm_release" "kube_prometheus_stack" {
  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = "69.7.4"
  namespace        = "monitoring"
  create_namespace = true
  wait             = false

  values = [
    <<-EOT
    grafana:
      enabled: true
      defaultDashboardsEnabled: true
      adminPassword: "notforproductionuse"
      service:
        type: ClusterIP
        port: 3000
      # Configure Grafana to run on system node pool
      nodeSelector:
        karpenter.sh/nodepool: system
      tolerations:
        - key: CriticalAddonsOnly
          operator: Exists
          effect: NoSchedule
    
    prometheus:
      prometheusSpec:
        serviceMonitorSelectorNilUsesHelmValues: false
        # Configure Prometheus to run on system node pool
        nodeSelector:
          karpenter.sh/nodepool: system
        tolerations:
          - key: CriticalAddonsOnly
            operator: Exists
            effect: NoSchedule
    
    # Configure Prometheus Operator to run on system node pool
    prometheusOperator:
      nodeSelector:
        karpenter.sh/nodepool: system
      tolerations:
        - key: CriticalAddonsOnly
          operator: Exists
          effect: NoSchedule
    
    # Configure AlertManager to run on system node pool
    alertmanager:
      alertmanagerSpec:
        nodeSelector:
          karpenter.sh/nodepool: system
        tolerations:
          - key: CriticalAddonsOnly
            operator: Exists
            effect: NoSchedule
    
    # Configure kube-state-metrics to run on system node pool
    kube-state-metrics:
      nodeSelector:
        karpenter.sh/nodepool: system
      tolerations:
        - key: CriticalAddonsOnly
          operator: Exists
          effect: NoSchedule
    
    # Configure node-exporter (runs on all nodes by default)
    nodeExporter:
      tolerations:
        - key: CriticalAddonsOnly
          operator: Exists
          effect: NoSchedule
    EOT
  ]

  depends_on = [module.eks]
}

resource "helm_release" "grafana_operator" {
  name       = "grafana-operator"
  namespace  = "monitoring"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana-operator"
  version    = "5.16.0"
  wait       = false

  values = [
    <<-EOT
    # Configure Grafana Operator to run on system node pool
    nodeSelector:
      karpenter.sh/nodepool: system
    tolerations:
      - key: CriticalAddonsOnly
        operator: Exists
        effect: NoSchedule
    
    # Also configure the operator deployment specifically
    deployment:
      nodeSelector:
        karpenter.sh/nodepool: system
      tolerations:
        - key: CriticalAddonsOnly
          operator: Exists
          effect: NoSchedule
    
    # Configure the operator container settings
    operator:
      scanAllNamespaces: true
    EOT
  ]

  depends_on = [module.eks, helm_release.kube_prometheus_stack]
}


resource "kubectl_manifest" "grafana_admin_credentials" {
  depends_on = [
    module.eks,
    module.eks.cluster_addons,
    helm_release.grafana_operator,
    helm_release.kube_prometheus_stack
  ]

  server_side_apply = true
  yaml_body         = <<-YAML
    apiVersion: v1
    kind: Secret
    metadata:
      name: grafana-admin-credentials
      namespace: monitoring
    data:
      admin-user: ${base64encode("admin")}
      admin-password: ${base64encode(var.grafana_admin_password)}
  YAML
}


resource "kubectl_manifest" "external_grafana" {
  depends_on = [
    module.eks,
    module.eks.cluster_addons,
    helm_release.grafana_operator,
    kubectl_manifest.grafana_admin_credentials,
    helm_release.kube_prometheus_stack
  ]

  server_side_apply = true
  yaml_body         = <<-YAML
    apiVersion: grafana.integreatly.org/v1beta1
    kind: Grafana
    metadata:
      name: external-grafana
      namespace: monitoring
      labels:
        dashboards: external-grafana
    spec:
      external:
        url: http://kube-prometheus-stack-grafana.monitoring.svc.cluster.local:3000
        adminUser:
          name: grafana-admin-credentials
          key: admin-user
        adminPassword:
          name: grafana-admin-credentials
          key: admin-password
  YAML
}

resource "kubectl_manifest" "vllm_grafana_dashboard_config" {
  depends_on = [
    module.eks,
    module.eks.cluster_addons,
    helm_release.kube_prometheus_stack
  ]

  server_side_apply = true
  yaml_body         = <<-YAML
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: vllm-grafana-dashboard-config
      namespace: monitoring
    data:
      vllm-dashboard.json: ${jsonencode(file("${path.module}/grafana-dashboards/vllm-dashboard.json"))}
  YAML
}

resource "kubectl_manifest" "ray_default_grafana_dashboard_config" {
  depends_on = [
    module.eks,
    module.eks.cluster_addons,
    helm_release.kube_prometheus_stack
  ]

  server_side_apply = true
  yaml_body         = <<-YAML
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: ray-grafana-default-dashboard-config
      namespace: monitoring
    data:
      ray-default-grafana-dashboard.json: ${jsonencode(file("${path.module}/grafana-dashboards/ray-default-grafana-dashboard.json"))}
  YAML
}

resource "kubectl_manifest" "ray_serve_grafana_dashboard_config" {
  depends_on = [
    module.eks,
    module.eks.cluster_addons,
    helm_release.kube_prometheus_stack
  ]

  server_side_apply = true
  yaml_body         = <<-YAML
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: ray-grafana-serve-dashboard-config
      namespace: monitoring
    data:
      ray-serve-grafana-dashboard.json: ${jsonencode(file("${path.module}/grafana-dashboards/ray-serve-grafana-dashboard.json"))}
  YAML
}

resource "kubectl_manifest" "ray_serve_deployment_grafana_dashboard_config" {
  depends_on = [
    module.eks,
    module.eks.cluster_addons,
    helm_release.kube_prometheus_stack
  ]

  server_side_apply = true
  yaml_body         = <<-YAML
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: ray-grafana-serve-deployment-dashboard-config
      namespace: monitoring
    data:
      ray-serve-deployment-grafana-dashboard.json: ${jsonencode(file("${path.module}/grafana-dashboards/ray-serve-deployment-grafana-dashboard.json"))}
  YAML
}

resource "kubectl_manifest" "dcgm_grafana_dashboard_config" {
  depends_on = [
    module.eks,
    module.eks.cluster_addons,
    helm_release.kube_prometheus_stack
  ]

  server_side_apply = true
  yaml_body         = <<-YAML
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: dcgm-dashboard-config
      namespace: monitoring
    data:
      dcgm-grafana-dashboard.json: ${jsonencode(file("${path.module}/grafana-dashboards/dcgm-grafana-dashboard.json"))}
  YAML
}
