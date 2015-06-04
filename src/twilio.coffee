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

  send: (envelope, strings...) ->
    body = strings.join "\n"
    user = envelope.user

    if body.substring(0,4) == 'http'
      @send_mms body, user.phone, (err, message) ->
        if err or not body?
          console.error("MMS:Error", err.status, err.code, err.message)
        else
          console.log "Sending reply MMS: #{message.sid}, #{body} to #{user.id}"

    else
      @send_sms body, user.phone, (err, message) ->
        if err or not body?
          console.error("SMS:Error", err.status, err.code, err.message)
        else
          console.log "Sending reply SMS: #{message.sid}, #{body} to #{user.id}"

  reply: (envelope, strings...) ->
    @send envelope, str for str in strings

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
    user.phone = from

    # Following the same name matching pattern as the Robot
    if @robot.alias
      alias = @robot.alias.replace(/[-[\]{}()*+?.,\\^$|#\s]/g, '\\$&') # escape alias for regexp
      newRegex = new RegExp("^(?:#{@robot.alias}[:,]?|#{@robot.name}[:,]?)", "i")
    else
      newRegex = new RegExp("^#{@robot.name}[:,]?", "i")

    # Prefix message if there is no match
    unless body.match(newRegex)
      body = (@robot.name + " " ) + body

    @receive new TextMessage user, body

  send_mms: (body, to, callback) ->
    console.log(body)
    @client.messages.create
      to: to
      from: @from
      media_url: body
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

