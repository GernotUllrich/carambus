#!/bin/bash
if sudo systemctl is-active --quiet puma-carambus_api.service
then
  echo "Service is running, performing restart"
  sudo systemctl restart puma-carambus_api.service
else
  echo "Service is not running, starting service"
  sudo systemctl start puma-carambus_api.service
fi
