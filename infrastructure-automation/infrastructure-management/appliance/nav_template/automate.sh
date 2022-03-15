#!/bin/sh
envsubst << EOF
apiVersion: v1
data:
  extensions: |
    [
      {
        "extension_point_id": "left_menu_folder",
        "extension_name": "dap-header-auto",
        "display_name": "Automate Infrastructure",
        "order_hint": 200,
        "match_permissions": "",
        "meta": {},
        "details": {
          "icon": "nav/icons/unified-workflow"
        }
      },
      {
        "extension_point_id": "left_menu_item",
        "extension_name": "dap-admin-auto-appliance",
        "display_name": "Infrastructure management",
        "order_hint": 210,
        "match_permissions": "",
        "meta": {},
        "details": {
          "window_open_target": "_blank",
          "target": "_blank",
          "parent_folder": "dap-header-auto",
          "href": "$im_url"
        }
      }
    ]
kind: ConfigMap
metadata:
  labels:
    app: ibm-infra-management-application
    icpdata_addon: "true"
    icpdata_addon_version: 1.0.0
  name: nav-extensions-automation-im
  namespace: $zen_namespace
EOF