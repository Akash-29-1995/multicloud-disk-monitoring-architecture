"""Lucidity disk-monitoring orchestrator.

Jenkins (or CLI) is a thin trigger. This package:
  authenticate → discover → filter → normalize inventory → hand off to Ansible.

AWS is implemented. GCP/Azure adapters are extension stubs.
"""

__version__ = "1.0.0"
