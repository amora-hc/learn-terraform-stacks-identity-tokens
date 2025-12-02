data "tfe_project" "default" {
  name         = var.tfc_project_name
  organization = var.tfc_organization_name
}

resource "tfe_oauth_client" "default" {
  name             = "GitHub-OAuth"
  api_url          = "https://api.github.com"
  http_url         = "https://github.com"
  service_provider = "github"
  organization     = var.github_organization
  oauth_token      = var.github_oauth_token
}

## OPTIONAL: reuse existing TFC oauth client for authentication to Github
/*data "tfe_oauth_client" "azuredevops" {
  organization = var.tfc_organization_name
  name         = var.tfc_oauth_client
}*/

# Create the variable set
resource "tfe_variable_set" "project_aws_creds" {
  name         = "project-aws-creds"
  description  = "AWS credentials for all workspaces in the project"
  organization = data.tfe_project.default.organization
}

resource "tfe_project_variable_set" "terraform_stacks" {
  project_id      = data.tfe_project.default.id
  variable_set_id = tfe_variable_set.project_aws_creds.id
}

resource "null_resource" "push_creds" {
  triggers = {
    workspace_id = tfe_variable_set.project_aws_creds.id
  }

  provisioner "local-exec" {
    command = "doormat login"
  }

  provisioner "local-exec" {
    command = "doormat aws tf-push variable-set --account ${var.aws_account_id} --id ${tfe_variable_set.project_aws_creds.id}"
  }
}

resource "tfe_workspace" "default" {
  depends_on          = [tfe_oauth_client.default, null_resource.push_creds]
  name                = var.tfc_workspace_name
  organization        = var.tfc_organization_name
  working_directory   = var.tfc_working_directory
  auto_apply          = var.auto_apply
  description         = "HCP Terraform AWS dynamic credentials"
  project_id          = data.tfe_project.default.id
  speculative_enabled = true
  terraform_version   = var.terraform_version

  trigger_patterns = [
    "${var.tfc_working_directory}/**"
  ]

  vcs_repo {
    branch         = "main"
    identifier     = format("%s/%s", var.github_organization, var.github_repository)
    oauth_token_id = tfe_oauth_client.default.oauth_token_id
  }

  lifecycle {
    ignore_changes = [
      tags,
      tag_names
    ]
  }
}

resource "tfe_variable" "hcp_organization_name" {
  key          = "hcp_organization_name"
  value        = var.tfc_organization_name
  category     = "terraform"
  workspace_id = tfe_workspace.default.id
}

resource "tfe_variable" "hcp_project_name" {
  key          = "hcp_project_name"
  value        = var.tfc_project_name
  category     = "terraform"
  workspace_id = tfe_workspace.default.id
}

resource "tfe_variable" "tfe_tf_default" {
  for_each     = var.tfc_terraform_variables
  key          = each.key
  value        = each.value.value
  sensitive    = each.value.sensitive
  category     = "terraform"
  workspace_id = tfe_workspace.default.id
}

resource "tfe_variable" "tfe_env_default" {
  for_each     = var.tfc_environment_variables
  key          = each.key
  value        = each.value.value
  sensitive    = each.value.sensitive
  category     = "env"
  workspace_id = tfe_workspace.default.id
}
