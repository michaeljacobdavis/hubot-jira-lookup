# Description:
#   Jira lookup when issues are heard
#
# Dependencies:
#   None
#
# Configuration:
#   HUBOT_USERNAME
#   HUBOT_PASSWORD
#   HUBOT_JIRA_URL
#   HUBOT_IGNORE_USERS (optional, format: "user1|user2", default is "jira|github")
#
# Commands:
#   None
#
# Author:
#   Matthew Finlayson <matthew.finlayson@jivesoftware.com> (http://www.jivesoftware.com)
#   Benjamin Sherman  <benjamin@jivesoftware.com> (http://www.jivesoftware.com)
#   Dustin Miller <dustin@sharepointexperts.com> (http://sharepointexperience.com)

module.exports = (robot) ->

  acceptanceCriteriaField = 'customfield_10302'
  ignored_users = process.env.HUBOT_IGNORE_USERS
  if ignored_users == undefined
    ignored_users = "jira|github"

  robot.hear /\b[a-zA-Z]{2,12}-[0-9]{1,10}\b/, (msg) ->

    return if msg.message.user.name.match(new RegExp(ignored_users, "gi"))

    issue = msg.match[0]
    user = process.env.HUBOT_USERNAME
    pass = process.env.HUBOT_PASSWORD
    url = process.env.HUBOT_JIRA_URL
    auth = 'Basic ' + new Buffer(user + ':' + pass).toString('base64')
    robot.http("#{url}/rest/api/latest/issue/#{issue}")
      .headers(Authorization: auth, Accept: 'application/json')
      .get() (err, res, body) ->
        try
          json = JSON.parse(body)
          json_acceptanceCriteria = ""
          if json.fields[acceptanceCriteriaField]
            json_acceptanceCriteria = "\n Acceptance:  "
            unless json.fields[acceptanceCriteriaField] is null or json.fields[acceptanceCriteriaField].nil? or json.fields[acceptanceCriteriaField].empty?
              json_acceptanceCriteria += json.fields[acceptanceCriteriaField]
          json_description = ""
          if json.fields.description
            json_description = "\n Description: "
            unless json.fields.description is null or json.fields.description.nil? or json.fields.description.empty?
              desc_array = json.fields.description.split("\n")
              for item in desc_array[0..2]
                json_description += item
          json_assignee = ""
          if json.fields.assignee
            json_assignee = "\n Assignee:    "
            unless json.fields.assignee is null or json.fields.assignee.nil? or json.fields.assignee.empty?
              unless json.fields.assignee.name.nil? or json.fields.assignee.name.empty?
                json_assignee += json.fields.assignee.name
          json_status = ""
          if json.fields.status
            json_status = "\n Status:      "
            unless json.fields.status is null or json.fields.status.nil? or json.fields.status.empty?
              unless json.fields.status.name.nil? or json.fields.status.name.empty?
                json_status += json.fields.status.name
          if process.env.HUBOT_SLACK_INCOMING_WEBHOOK?
            robot.emit 'slack.attachment',
              message: msg.message
              content:
                text: 'Issue details'
                fallback: 'Issue:       #{json.key}: #{json_acceptanceCriteria}#{json_description}#{json_assignee}#{json_status}\n Link:        #{process.env.HUBOT_JIRA_URL}/browse/#{json.key}\n'
                fields: [
                  {
                  title: 'Acceptance Criteria'
                  value: "#{json_acceptanceCriteria}"
                  },
                  {
                  title: 'Description'
                  value: "#{json_description}"
                  },
                  {
                  title: 'Assignee'
                  value: "#{json_assignee}"
                  },
                  {
                  title: 'Status'
                  value: "#{json_status}"
                  },
                  {
                  title: 'Link'
                  value: "<#{process.env.HUBOT_JIRA_URL}/browse/#{json.key}>"
                  }
                ]
          else
            msg.send "Issue:       #{json.key}: #{json_acceptanceCriteria}#{json_description}#{json_assignee}#{json_status}\n Link:        #{process.env.HUBOT_JIRA_URL}/browse/#{json.key}\n"
        catch error
          console.log error
