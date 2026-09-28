# frozen_string_literal: true

# =============================================================================
# ACTIVE MODEL SERIALIZERS INITIALIZER
# =============================================================================
# Configures active_model_serializers gem behavior.
#
# adapter: :json_api — Use JSON:API format (data/attributes structure)
# adapter: :json     — Use flat JSON format (simpler, easier for beginners)
# adapter: :attributes — Default AMS format (flat, no root key)
#
# We use :json_api for industry-standard format. Clients know to look for
# the `data` key in responses.
# =============================================================================
ActiveModelSerializers.config.adapter = :json
ActiveModelSerializers.config.key_transform = :underscore
