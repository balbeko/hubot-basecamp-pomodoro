
xml2js = require 'xml2js'
data2xml = require('data2xml')
XML    = new xml2js.Parser()

module.exports = (robot)->
  String::hideToken = ->
    tmp = Array(@.length - 6).join("*")
    tmp += @.slice(@.length - 6)
    tmp

  robot.hear /^!debug/i, (msg) ->
    console.log msg.message.user
    
  robot.hear /^!(config|cfg|cf) help/i, (msg)->
    userName   = msg.message.user.name 
    msg.send "#{userName}, you may set up your credentials here"
    msg.send "i.e. !config add basecamp key your_key_here"

  robot.hear /^!(config|cfg|cf) show/i, (msg) ->
    user       = msg.message.user.id
    userName   = msg.message.user.name 
    mind       = robot.brain.data.users[user]
    if not mind.basecamp_configured
      msg.send "#{userName}, your basecamp credentials are not congfigured. Do '!config help' or '!config add basecamp key WoopWooopWoo00p'"
      return
    msg.send "#{userName}, your configuration is:"
    msg.send "Basecamp API token: #{mind.basecamp_token.hideToken()}" 
    msg.send "Projects count: #{mind.basecamp_projects.length}" 

    if mind.basecamp_current_project == ""
      msg.send "Selected project: none."
      msg.send "You can do '!projects list' and '!project select' to specify what project you wish to track time to."
      return
 
    for project in mind.basecamp_projects
      msg.send "Selected project: #{project.name}" if project.id == mind.basecamp_current_project   
  

  robot.hear /^!(config|cfg|cf) (add|set) (.*) (token|key|k) (.*)/i, (msg)->
    service    = msg.match[3]
    bc_account = process.env.BASECAMP_ACCOUNT
    bc_token   = msg.match[5]
    user       = msg.message.user.id
    userName   = msg.message.user.name 
    mind       = robot.brain.data.users[user]
    if service in ['bc', 'basecamp', 'bcamp']
      mind.basecamp_token   = bc_token
      mind.basecamp_account = bc_account 
      basecamp_request msg, "/me.xml", bc_token, bc_account, (bc_data) ->
        if bc_data?
          mind.basecamp_user_id = bc_data.id["#"]
          getProjects msg, bc_token, bc_account, (data) ->
            robot.brain.data.users[user].basecamp_projects = data
          mind.basecamp_current_project = ""
          mind.basecamp_recent_projects = []  
          mind.basecamp_configured = true
          msg.send "#{userName}, your basecamp token saved. Your basecamp user id = #{bc_data.id['#']}"
        else
          mind.basecamp_configured = false
          mind.basecamp_token   = ""
          mind.basecamp_account = "" 
          mind.basecamp_user_id = ""
          mind.basecamp_projects = []
          mind.basecamp_current_project = ""
          mind.basecamp_recent_projects = []

          msg.send "#{userName}, your credentials seems to be wrong."
    else
      msg.send "#{userName}, i dont know what is '#{service}'"

  robot.hear /^!(config|cfg|cf) (reload|read|update|get|rld|up|)/i, (msg)->
    bc_account = process.env.BASECAMP_ACCOUNT
    user       = msg.message.user.id
    userName   = msg.message.user.name 
    mind       = robot.brain.data.users[user]
    bc_token   = mind.basecamp_token
    basecamp_request msg, "/me.xml", bc_token, bc_account, (bc_data) ->
      if bc_data?
        mind.basecamp_user_id = bc_data.id["#"]
        getProjects msg, bc_token, bc_account, (data) ->
          robot.brain.data.users[user].basecamp_projects = data
        mind.basecamp_current_project = ""
        mind.basecamp_recent_projects = []  
        mind.basecamp_configured = true
        msg.send "#{userName}, your basecamp projects list have been updated"
      else
        mind.basecamp_configured = false
        mind.basecamp_token   = ""
        mind.basecamp_account = "" 
        mind.basecamp_user_id = ""
        mind.basecamp_projects = []
        mind.basecamp_current_project = ""
        mind.basecamp_recent_projects = []

        msg.send "#{userName}, your credentials seems to be wrong."
    else
      msg.send "#{userName}, i dont know what is '#{service}'"
  
  robot.hear /^!(project|projects|prj|proj|p) (list|l)/i, (msg) ->
    user       = msg.message.user.id
    userName   = msg.message.user.name 
    mind       = robot.brain.data.users[user]
    projects   = ""
    if not mind.basecamp_configured
      msg.send "#{userName}, please confugure basecamp credentials first"
      return
    #console.log mind.basecamp_projects
    projects = "#{userName}, here is a list of projects you have access to: \n\n"
    for project in mind.basecamp_projects
      #msg.send "#{mind.basecamp_projects.indexOf(project) + 1}: #{project.name}"
      projects += "#{mind.basecamp_projects.indexOf(project) + 1}: #{project.name} \n"

    msg.send "#{projects} \n\n You can select one by '!project select <number>'"
  
  robot.hear /^!(project|projects|prj|proj|p) (select|sel|s) (\d+)/i, (msg) ->
    user       = msg.message.user.id
    userName   = msg.message.user.name 
    mind       = robot.brain.data.users[user]
    console.log mind
    if not mind.basecamp_configured
      msg.send "#{userName}, please configure basecamp credentials first"
      return
    project    = msg.match[3]
    mind.basecamp_current_project = mind.basecamp_projects[project - 1].id
    mind.basecamp_recent_projects.push(mind.basecamp_projects[project - 1].id)

    msg.send "#{userName}, your time will be tracked to #{mind.basecamp_projects[project - 1].name}"

  robot.hear /^!pom (.*)/i, (msg) ->
    description = msg.match[1]
    user       = msg.message.user.id
    userName   = msg.message.user.name 
    mind       = robot.brain.data.users[user]
    d          = new Date()
    project_id = mind.basecamp_current_project
    bc_account = mind.basecamp_account
    bc_token   = mind.basecamp_token

    if not mind.basecamp_configured
      msg.send "#{userName}, your basecamp credentials are not congfigured. Do '!config help' or '!config add basecamp key WoopWooopWoo00p'"
      return

    if mind.basecamp_current_project == ""
      msg.send "Selected project: none."
      msg.send "You can do '!projects list' and '!project select' to specify what project you wish to track time to."
      return

    td = 
      "person-id"   : mind.basecamp_user_id
      "date"        : "#{d.getFullYear()}-#{d.getMonth()+1}-#{d.getDate()}"
      "hours"       : "0.5"
      "description" : description

    time_data = data2xml "time-entry", td
    basecamp_post msg, time_data, "/projects/#{project_id}/time_entries.xml", bc_token, bc_account, (code) ->
      if code == 201
        msg.send "#{userName}, your pom recorded."
      else
        msg.send "#{userName}, something went wrong."

    
  
getProjects = (msg, token, acc, handler) ->
  basecamp_request msg, "/projects.xml", token, acc, (entries, data)->
    data = []
    for project in entries.project
      obj = 
        id: project.id["#"]
        name: "#{project.company.name} - #{project.name}"
      data.push obj
    handler data

basecamp_request = (msg, url, token, acc, handler) ->
  console.log "call: basecamp_request"
  basecamp_key = "#{token}"
  auth = new Buffer("#{basecamp_key}:X").toString('base64')
  basecamp_url = "https://#{acc}.basecamphq.com"
  msg.http("#{basecamp_url}/#{url}")
    .headers(Authorization: "Basic #{auth}", Accept: "application/xml")
      .get() (err, res, body) ->
        if err
          msg.send "Basecamp says: #{err}"
          return
        XML.parseString body, (err, result) =>
          handler result 

basecamp_post = (msg, data, url, token, acc, handler) ->
  basecamp_key = "#{token}"
  auth = new Buffer("#{basecamp_key}:X").toString('base64')
  basecamp_url = "https://#{acc}.basecamphq.com"
  msg.http("#{basecamp_url}/#{url}")
    .headers(Authorization: "Basic #{auth}", Accept: "application/xml", 'Content-Type': "application/xml")
      .post(data) (err, res, body) ->
        if err
          msg.send "Basecamp says: #{err}"
          return
        handler res.statusCode








###
