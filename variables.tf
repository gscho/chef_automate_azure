variable "location" {
  type        = string
  description = "The Azure location where components should be created."
}

variable "tags" {
  type    = map(string)
  default = {}
}
