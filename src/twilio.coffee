{Robot, Adapter, TextMessage}   = require("hubot")

HTTP    = require "http"
QS      = require "querystring"

class Twilio extends Adapter
  constructor: (robot) ->
    @sid   = process.env.HUBOT_SMS_SID
    @token = process.env.HUBOT_SMS_TOKEN
    @from  = process.env.HUBOT_SMS_FROM
    @robot = robot
    super robot

  send: (user, strings...) ->
    body = strings.join "\n"

    @send_sms body, user.id, (err, message) ->
      if err or not body?
        console.log "Error sending reply SMS: #{err}"
        JSON.stringify(err, null, 4)
      else
        console.log "Sending reply SMS: #{message.sid}, #{body} to #{user.id}"

  reply: (user, strings...) ->
    @send user, str for str in strings

  respond: (regex, callback) ->
    @hear regex, callback

  run: ->
    self = @

    @robot.router.get "/hubot/sms", (request, response) =>
      payload = QS.parse(request.url)

      if payload.Body? and payload.From?
        console.log "Received SMS: #{payload.Body} from #{payload.From}"
        @receive_sms(payload.Body, payload.From)

      response.writeHead 200, 'Content-Type': 'text/plain'
      response.end()

    @client = require('twilio')(@sid, @token)

    self.emit "connected"

  receive_sms: (body, from) ->
    return if body.length is 0
    user = @robot.brain.userForId from

    nameRegex = "^[@]?#{@robot.name}"
    if body.match nameRegex is null
      console.log "Adding #{@robot.name} as a prefix to received SMS"
      body = @robot.name + ' ' + body

    @receive new TextMessage user, body

  send_sms: (body, to, callback) ->     
    @client.messages.create
      to: to
      from: @from
      body: body
    , (err, message) ->
      if err
        callback err
      else if res.statusCode is 201
        json = JSON.parse(message)
        callback null, message
      else
        json = JSON.parse(message)
        callback message
      return

exports.Twilio = Twilio

exports.use = (robot) ->
  new Twilio robot

