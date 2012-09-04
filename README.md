# Basecamp-Pomodoro Hubot Script
A simple script that helps to track time to Basecamp using Pomodoro Technique

# Typical workflow
Befor deploy - configure BASECAMP_ACCOUNT environment var to specify right basecamp account id.

Then type to your chat  
`!basecamp config add key your_basecamp_api_key` to specify your api token  
`!projects list` to get a list of your projects  
`!project select porject_id` to select a project to track time to  
`!pom some_description` to record 30 minutes to selected project  

---

Some extra commands available:  
`!config reload` to reread configuration  
`!config show` to show current config  