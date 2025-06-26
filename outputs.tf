output "graphql_endpoint" {
  description = "GraphQL API endpoint"
  value       = aws_appsync_graphql_api.main.uris["GRAPHQL"]
}

output "api_key" {
  description = "API Key for GraphQL API"
  value       = aws_appsync_api_key.main.key
  sensitive   = true
}

output "api_id" {
  description = "GraphQL API ID"
  value       = aws_appsync_graphql_api.main.id
}
