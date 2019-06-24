module "label" {
  source    = "git::https://github.com/cloudposse/terraform-null-label.git?ref=tags/0.12.0"
  namespace = var.product_name
  stage     = var.instance_name
  delimiter = "__"
}


## ECS task exectution role

resource "aws_iam_role" "scheduled_task_ecs_execution" {
  name               = "${module.label.id}-st-ecs-execution-role"
  assume_role_policy = file("${path.module}/policies/scheduled-task-ecs-execution-assume-role-policy.json")
}

data "template_file" "scheduled_task_ecs_execution_policy" {
  template = file("${path.module}/policies/scheduled-task-ecs-execution-policy.json")
}

resource "aws_iam_role_policy" "scheduled_task_ecs_execution" {
  name   = "${module.label.id}-st-ecs-execution-policy"
  role   = aws_iam_role.scheduled_task_ecs_execution.id
  policy = data.template_file.scheduled_task_ecs_execution_policy.rendered
}

## ECS task role

resource "aws_iam_role" "scheduled_task_ecs" {
  name               = "${module.label.id}-st-ecs-role"
  assume_role_policy = file("${path.module}/policies/scheduled-task-ecs-assume-role-policy.json")
}

## Cloudwatch event role

resource "aws_iam_role" "scheduled_task_cloudwatch" {
  name               = "${module.label.id}-st-cloudwatch-role"
  assume_role_policy = file("${path.module}/policies/scheduled-task-cloudwatch-assume-role-policy.json")
}

data "template_file" "scheduled_task_cloudwatch_policy" {
  template = file("${path.module}/policies/scheduled-task-cloudwatch-policy.json")

  vars = {
    task_execution_role_arn = aws_iam_role.scheduled_task_ecs_execution.arn
  }
}

resource "aws_iam_role_policy" "scheduled_task_cloudwatch_policy" {
  name   = "${module.label.id}-st-cloudwatch-policy"
  role   = aws_iam_role.scheduled_task_cloudwatch.id
  policy = data.template_file.scheduled_task_cloudwatch_policy.rendered
}

## ECS task definition

resource "aws_ecs_task_definition" "scheduled_task" {
  family                   = "${module.label.id}-${var.task_name}"
  container_definitions    = var.container_definitions
  requires_compatibilities = ["EC2"]
  network_mode             = var.network_mode
//  execution_role_arn       = aws_iam_role.scheduled_task_ecs_execution.arn
  task_role_arn            = aws_iam_role.scheduled_task_ecs.arn
  cpu                      = var.cpu
  memory                   = var.memory
}

## Cloudwatch event

resource "aws_cloudwatch_event_rule" "scheduled_task" {
  name                = "${module.label.id}__${var.task_name}__scheduled_task"
  description         = "Run ${module.label.id} ${var.task_name} task at a scheduled time (${var.schedule_expression})"
  schedule_expression = var.schedule_expression
}

resource "aws_cloudwatch_event_target" "scheduled_task" {
  target_id = "${module.label.id}_scheduled_task_target"
  rule      = aws_cloudwatch_event_rule.scheduled_task.name
  arn       = var.cluster_arn
  role_arn  = aws_iam_role.scheduled_task_cloudwatch.arn

  ecs_target {
    task_count          = var.task_count
    task_definition_arn = aws_ecs_task_definition.scheduled_task.arn
  }
}
