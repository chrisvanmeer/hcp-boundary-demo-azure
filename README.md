# HCP Boundary with self managed workers

## Synopsis

Get secure access to your private resources through HCP Boundary.  
In stead of traditional solutions like jump-boxes or VPN's, (a part of)  
Boundary does not need any ingress firewall rules. In stead, it only needs  
egress access to an upstream worker.  

## Requirements

This repository is meant for using during a live demo and expects:

- You have Terraform installed locally
- You have access to HCP
- You have a valid Azure subscription
  - You are already authenticated through `az login`

## Deployment

Terraform will provision the following:  
(..)