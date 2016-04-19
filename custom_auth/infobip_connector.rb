{
    title: 'Infobip',

    connection: {
        fields: [
            {
                name: 'api_key',
                control_type: 'password',
                optional: false
            }
        ],

        authorization: {
            type: 'custom_auth',

            credentials: ->(connection) {
              headers('Authorization': "App #{connection['api_key']}")
            }
        }
    },

    test: ->(connection) {
      get("https://api.infobip.com/sms/1/logs")
    },

    object_definitions: {
        send_sms_request: {
            fields: ->() {
              [
                  {name: 'from'},
                  {name: 'to'},
                  {name: 'text'}
              ]
            }
        },
        sent_sms_status: {
            fields: ->() {
              [
                  {name: 'groupId', type: :integer},
                  {name: 'groupName'},
                  {name: 'id', type: :integer},
                  {name: 'name'},
                  {name: 'description'}
              ]
            }
        },
        sent_sms_info: {
            fields: ->() {
              [
                  {name: 'to'},
                  {name: 'status', type: :object_definitions['sent_sms_status']},
                  {name: 'smsCount', type: :integer},
                  {name: 'messageId'}
              ]
            }
        },
        send_sms_response: {
            fields: ->() {
              [
                  {name: 'messages', type: :array, of: :object, properties: :object_definitions['sent_sms_info']}
              ]
            }
        },
        received_sms_info: {
            fields: ->() {
              [
                  {name: 'messageId'},
                  {name: 'from'},
                  {name: 'to'},
                  {name: 'text'},
                  {name: 'cleanText'},
                  {name: 'keyword'},
                  {name: 'smsCount', type: :integer}
              ]
            }
        },
        received_sms_response: {
            fields: ->() {
              [
                  {name: 'results', type: :array, of: :object, properties: :object_definitions['received_sms_info']}
              ]
            }
        }
    },

    actions: {
        send_sms: {
            input_fields: ->(object_definitions) {
              object_definitions['send_sms_request'].required('to')
            },
            execute: ->(connection, input) {
              post("https://api.infobip.com/sms/1/text/single", input)['send_sms_request']
            },
            output_fields: ->(object_definitions) {
              object_definitions['send_sms_response']
            }
        }
    },
    triggers: {
        sms_received: {
            input_fields: ->() {
              [
                  {name: 'received_since', type: :timestamp}
              ]
            },
            poll: ->(connection, input, last_received_since) {
              received_since = last_received_since || input['received_since'] || Time.now

              received_since_formatted = received_since.strftime("%FT%T.%L%:z")
              received_messages = get("https://api.infobip.com/sms/1/inbox/logs").
                  params(receivedSince: received_since_formatted)

              received_sms_info = received_messages['results']

              next_received_since = received_sms_info.last['receivedAt'] unless received_sms_info.length == 0
              {
                  events: received_sms_info,
                  next_poll: next_received_since,
                  can_poll_more: received_sms_info.length >= 2
              }
            },
            dedup: ->(received_sms_info) {
              received_sms_info['messageId']
            },
            output_fields: ->(object_definitions) {
              object_definitions['received_sms_info']
            }
        }
    }
}