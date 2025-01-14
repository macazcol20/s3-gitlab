## THIS TO AUTHENTICATE TO ECR, DON'T CHANGE IT
provider "aws" {
  region = "us-east-1"
  alias  = "virginia"
}

provider "aws" {
  region = local.region
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

provider "kubectl" {
  apply_retry_count      = 10
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  load_config_file       = false
  token                  = data.aws_eks_cluster_auth.this.token
}

data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}

data "aws_ecrpublic_authorization_token" "token" {
  provider = aws.virginia
}

data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  name            = "mimeo-karpenter"
  cluster_version = "1.31"
  region          = var.region
  node_group_name = "managed-ondemand"
  node_iam_role_name = module.eks_blueprints_addons.karpenter.node_iam_role_name

  vpc_id              = module.vpc.vpc_id
  vpc_cidr            = module.vpc.vpc_cidr_block
  public_subnets_ids  = module.vpc.public_subnets
  private_subnets_ids = module.vpc.private_subnets
  database_subnets_id = module.vpc.database_subnets
  subnets_ids         = concat(local.public_subnets_ids, local.private_subnets_ids, local.database_subnets_id)

  # vpc_cidr = "10.0.0.0/16"
  ## NOTE: You might need to change this less number of AZs depending on the region you're deploying to
  azs = slice(data.aws_availability_zones.available.names, 0, 3)
  secondary_cidr = "10.1.0.0/16"  # secondary
  tags = {
    blueprint = local.name
  }
}

################################################################################
# Cluster
################################################################################
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.23.0"

  cluster_name                   = local.name
  cluster_version                = local.cluster_version
  cluster_endpoint_public_access = true

  cluster_addons = {
    kube-proxy = { most_recent = true }
    coredns    = { most_recent = true }

    vpc-cni = {
      most_recent    = true
      before_compute = true
      service_account_role_arn = module.vpc_cni_irsa.iam_role_arn   ## collins
      configuration_values = jsonencode({
        env = {
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
      })
    }
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = local.private_subnets_ids

  create_cloudwatch_log_group              = false
  create_cluster_security_group            = false
  create_node_security_group               = false
  authentication_mode                      = "API_AND_CONFIG_MAP"
  enable_cluster_creator_admin_permissions = true

  eks_managed_node_groups = {
    mg_5 = {
      node_group_name = "managed-ondemand"
      instance_types  = ["m4.large", "m5.large", "m5a.large", "m5ad.large", "m5d.large", "t2.large", "t3.large", "t3a.large", "t2.medium", "c6a.4xlarge", "m5.xlarge"] #,  , "t4g.medium"] 
      create_security_group = false
      # additional_security_group_ids = [module.efs.efs_security_group_id]   ## collins add this for the sake of efs
      subnet_ids   = module.vpc.private_subnets
      max_size     = 2
      desired_size = 2
      min_size     = 2

      # Launch template configuration
      create_launch_template = true              # false will use the default launch template
      launch_template_os     = "amazonlinux2eks" # amazonlinux2eks or bottlerocket

      labels = {
        intent = "control-apps"
      }
    }

    # general-mimeo-workers = {
    #   node_group_name = "general-mimeo-workers"
    #   instance_types  = ["t3.medium"]
    #   desired_size    = 2
    #   max_size        = 3
    #   min_size        = 1
    #   subnet_ids      = module.vpc.private_subnets
    #   labels = {
    #     workload = "general-mimeo-workers"
    #   }
    #   # taints = [
    #   #   {
    #   #     key    = "workload"
    #   #     value  = "general-mimeo-workers"
    #   #     effect = "NO_SCHEDULE"
    #   #   }
    #   # ]
    # }
  }

  tags = merge(local.tags, {
    "karpenter.sh/discovery" = local.name
  })

  ####### collins add rules for istio  ##################################
  node_security_group_additional_rules = {
    ingress_15017 = {
      description                   = "Cluster API - Istio Webhook namespace.sidecar-injector.istio.io"
      protocol                      = "TCP"
      from_port                     = 15017
      to_port                       = 15017
      type                          = "ingress"
      source_cluster_security_group = true
    }
    ingress_15012 = {
      description                   = "Cluster API to nodes ports/protocols"
      protocol                      = "TCP"
      from_port                     = 15012
      to_port                       = 15012
      type                          = "ingress"
      source_cluster_security_group = true
    }
  }
  ####### added  rules for istio above  #########################################
}

####### [Addons link](https://github.com/aws-ia/terraform-aws-eks-blueprints-addons)
####### [Addons version  "1.16.3" ]

module "eks_blueprints_addons" {
  source  = "../modules/eks-addons"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn
  enable_argocd                                = false
  enable_argo_rollouts                         = false
  enable_argo_workflows                        = false  # use own bootstrap
  enable_secrets_store_csi_driver              = true
  enable_secrets_store_csi_driver_provider_aws = true
  enable_kube_prometheus_stack                 = false
  enable_external_secrets = true
  enable_ingress_nginx    = true

  # Wait for all Cert-manager related resources to be ready
  enable_cert_manager = true
  cert_manager = {
    wait = true
  }


  create_delay_dependencies = [for prof in module.eks.eks_managed_node_groups : prof.node_group_arn]

  enable_aws_load_balancer_controller = true
  aws_load_balancer_controller = {
    set = [{
      name  = "enableServiceMutatorWebhook"
      value = "false"
    }]
  }
  
  eks_addons = {
  aws-ebs-csi-driver = {
    service_account_role_arn = module.ebs_csi_driver_irsa.iam_role_arn
  }
  ## collins adding efs addon
  # aws-efs-csi-driver = {
  #   service_account_role_arn = module.efs_csi_driver_irsa.iam_role_arn
  # }
}

  enable_karpenter = true

  karpenter = {
    chart_version       = "1.0.1"
    repository_username = data.aws_ecrpublic_authorization_token.token.user_name
    repository_password = data.aws_ecrpublic_authorization_token.token.password
  }
  karpenter_enable_spot_termination          = true
  karpenter_enable_instance_profile_creation = true
  karpenter_node = {
    iam_role_use_name_prefix = false
  }
  
  helm_releases = {
    # prometheus-adapter = {
    #   description      = "A Helm chart for k8s prometheus adapter"
    #   namespace        = "prometheus-adapter"
    #   create_namespace = true
    #   chart            = "prometheus-adapter"
    #   chart_version    = "4.2.0"
    #   repository       = "https://prometheus-community.github.io/helm-charts"
    #   values = [
    #     <<-EOT
    #       replicas: 2
    #       podDisruptionBudget:
    #         enabled: true
    #     EOT
    #   ]
    # }
    # gpu-operator = {
    #   description      = "A Helm chart for NVIDIA GPU operator"
    #   namespace        = "gpu-operator"
    #   create_namespace = true
    #   chart            = "gpu-operator"
    #   chart_version    = "v23.9.1"
    #   repository       = "https://nvidia.github.io/gpu-operator"
    #   values = [
    #     <<-EOT
    #       operator:
    #         defaultRuntime: containerd
    #     EOT
    #   ]
    # }
  }
  tags = local.tags
}

module "ebs_csi_driver_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.44.0"

  role_name_prefix = "${module.eks.cluster_name}-ebs-csi-driver-"

  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  tags = local.tags
}

module "aws-auth" {
  source  = "terraform-aws-modules/eks/aws//modules/aws-auth"
  version = "~> 20.0"

  manage_aws_auth_configmap = true

  aws_auth_roles = [
    {
      rolearn  = module.eks_blueprints_addons.karpenter.node_iam_role_arn
      username = "system:node:{{EC2PrivateDNSName}}"
      groups   = ["system:bootstrappers", "system:nodes"]
    },
  ]

  aws_auth_users = [
    {
      userarn  = "arn:aws:iam::440744236785:user/cafanwi@kapistio.com"
      username = "cafanwi@kapistio.com"
      groups   = ["system:masters"]
    },
    {
      userarn  = "arn:aws:iam::440744236785:user/crose@kapistio.com"
      username = "crose@kapistio.com"
      groups   = ["system:masters"]
    },
    {
      userarn  = "arn:aws:iam::440744236785:user/michael@kapistio.com"
      username = "michael@kapistio.com"
      groups   = ["system:masters"]
    },
  ]
}

#---------------------------------------------------------------
# Supporting Resources
#---------------------------------------------------------------
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.5.0"

  name = "mimeo-vpc"
  cidr = "10.0.0.0/16"
  secondary_cidr_blocks = [local.secondary_cidr]
  azs             = data.aws_availability_zones.available.names
  private_subnets = ["10.0.0.0/22", "10.0.4.0/22", "10.0.8.0/22"]
  public_subnets  = ["10.0.100.0/22", "10.0.104.0/22", "10.0.108.0/22"]
  database_subnets     = ["10.0.77.0/24", "10.0.78.0/24", "10.0.79.0/24", "10.1.15.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true
  enable_vpn_gateway = false



  public_subnet_tags = {
    "kubernetes.io/cluster/${local.name}" = "shared"
    "kubernetes.io/role/elb"              = 1
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.name}" = "shared"
    "kubernetes.io/role/internal-elb"     = 1
    "karpenter.sh/discovery"              = local.name
  }

  tags = local.tags
}


# #---------------------------------------------------------------
# # Add EFS Resources  ## collins add this for the sake of efs
# #---------------------------------------------------------------

# module "efs_csi_driver_irsa" {
#   source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
#   version = "5.44.0"

#   role_name_prefix = "${module.eks.cluster_name}-efs-csi-driver-"
#   attach_vpc_cni_policy              = true
#   vpc_cni_enable_ipv4                = true
#   attach_efs_csi_policy = true

#   oidc_providers = {
#     efs = {
#       provider_arn               = module.eks.oidc_provider_arn
#       namespace_service_accounts = ["kube-system:efs-csi-controller-sa"]
#     }
#   }
  
#   tags = local.tags
# }

# #-----------------------------------------------------------
# # Add VPC  cni_irsa
# #------------------------------------------------------------
module "vpc_cni_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name_prefix      = "VPC-CNI-IRSA"
  attach_vpc_cni_policy = true
  vpc_cni_enable_ipv4   = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-node"]
    }
  }
}

# #-----------------------------------------------------------
# # Add EFS 
# #------------------------------------------------------------
# module "attach_efs_csi_role" {
#   source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

#   role_name             = "efs-csi"
#   attach_efs_csi_policy = true

#   oidc_providers = {
#     ex = {
#       provider_arn               = module.eks.oidc_provider_arn
#       namespace_service_accounts = ["kube-system:efs-csi-controller-sa"]
#     }
#   }

#   tags = local.tags
# }

# resource "aws_security_group" "allow_nfs" {
#   name        = "allow nfs for efs"
#   description = "Allow NFS inbound traffic"
#   vpc_id      = local.vpc_id

#   ingress {
#     description = "NFS from VPC"
#     from_port   = 2049
#     to_port     = 2049
#     protocol    = "tcp"
#     cidr_blocks = [local.vpc_cidr]
#   }

#   egress {
#     from_port        = 0
#     to_port          = 0
#     protocol         = "-1"
#     cidr_blocks      = ["0.0.0.0/0"]
#     ipv6_cidr_blocks = ["::/0"]
#   }

# }


# resource "aws_efs_file_system" "mimeo_node_efs" {
#   creation_token = "efs-for-mimeo-node"
#   encrypted      = true # collins
# }

# resource "aws_efs_mount_target" "mimeo_node_efs_mt_0" {
#   file_system_id  = aws_efs_file_system.mimeo_node_efs.id
#   subnet_id       = module.vpc.private_subnets[0]
#   security_groups = [aws_security_group.allow_nfs.id]
# }

# resource "aws_efs_mount_target" "mimeo_node_efs_mt_1" {
#   file_system_id  = aws_efs_file_system.mimeo_node_efs.id
#   subnet_id       = module.vpc.private_subnets[1]
#   security_groups = [aws_security_group.allow_nfs.id]
# }
