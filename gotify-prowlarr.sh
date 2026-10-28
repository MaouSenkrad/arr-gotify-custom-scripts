#!/bin/bash

## https://wiki.servarr.com/en/prowlarr/custom-scripts

# ----------- GOTIFY CONFIGURATION -----------
GOTIFY_URL=""
GOTIFY_TOKEN=""
PRIORITY=5
# --------------------------------------------

## Prowlarr Event Types:
# +Test
# +HealthIssue
# +HealthRestored
# +ApplicationUpdate

# Emoji Kitchen Turtles, used as the poster for non-media alerts
TURTLE_THUMBUP="https://www.gstatic.com/android/keyboard/emojikitchen/20260202/u1f44d/u1f44d_u1f422.png"
TURTLE_COMPUTER="https://www.gstatic.com/android/keyboard/emojikitchen/20240206/u1f4bb/u1f4bb_u1f422.png"
TURTLE_SAD="https://www.gstatic.com/android/keyboard/emojikitchen/20201001/u1f622/u1f622_u1f422.png"
TURTLE_HAPPY="https://www.gstatic.com/android/keyboard/emojikitchen/20201001/u1f604/u1f604_u1f422.png"
TURTLE_THINK="https://www.gstatic.com/android/keyboard/emojikitchen/20260202/u1f914/u1f914_u1f422.png"

# Fallback values if Prowlarr env variables are empty
APP_NAME="${prowlarr_instancename:-Prowlarr}"
EVENT_TYPE="${prowlarr_eventtype:-Test}"

# Default Poster 
POSTER_URL="${TURTLE_THUMBUP}"

# Handle Prowlarr's Test Event
if [[ "${EVENT_TYPE}" == "Test" ]]; then

    TITLE="${APP_NAME} - Test Successful"
    MESSAGE="
If you are seeing this, **${APP_NAME}** successfully ran the Gotify script!  
![](${POSTER_URL})"

# Handle Prowlarr's Update Event
elif [[ "${EVENT_TYPE}" == "ApplicationUpdate" ]]; then
    TITLE="${APP_NAME} has Updated"
    # If length of prowlarr_update_message is zero or if returned false (-1)
    if [[ -z "${prowlarr_update_message}" || "${prowlarr_update_message}" == "-1" ]]; then
        MESSAGE="
**${APP_NAME}** has updated from *${prowlarr_update_previousversion}* to *${prowlarr_update_newversion}*  
![](${POSTER_URL})"
    else # Include prowlarr_update_message
        MESSAGE="
**${APP_NAME}** has updated from *${prowlarr_update_previousversion}* to *${prowlarr_update_newversion}*  
***Update Message:*** *${prowlarr_update_message}*  
![](${POSTER_URL})"
    fi

elif [[ "${EVENT_TYPE}" == "HealthIssue" ]]; then
    if [[ "${prowlarr_health_issue_type}" == *"Update"* ]]; then
        POSTER_URL="${TURTLE_COMPUTER}"
        TITLE="${APP_NAME} - Update Detected"
    else
        POSTER_URL="${TURTLE_SAD}"
        TITLE="${APP_NAME} - Health Degraded"
    fi

    MESSAGE="
**Event Level:** ${prowlarr_health_issue_level}  
**Event Source:** ${prowlarr_health_issue_type}  
**Event Message:** *${prowlarr_health_issue_message:-None}*  
**Wiki Link:** ${prowlarr_health_issue_wiki:-None}  
![](${POSTER_URL})"

elif [[ "${EVENT_TYPE}" == "HealthRestored" ]]; then
    if [[ "${prowlarr_health_restored_type}" == *"Update"* ]]; then 
        POSTER_URL="${TURTLE_THUMBUP}"
        TITLE="${APP_NAME} - Update Completed"

    else
        POSTER_URL="${TURTLE_SAD}"
        TITLE="${APP_NAME} - Health Improved"
    fi
    
    MESSAGE="
**Event Level:** ${prowlarr_health_restored_level}  
**Event Source:** ${prowlarr_health_restored_type}  
**Event Message:** *${prowlarr_health_restored_message:-None}*  
**Wiki Link:** ${prowlarr_health_restored_wiki:-None}  
![](${POSTER_URL})"

else
    # Ignore other events gracefully
    exit 0
fi

# Construct JSON payload with jq, utilizing Gotify's Markdown display extra
PAYLOAD=$(jq -n \
    --arg title "${TITLE}" \
    --arg msg "${MESSAGE}" \
    --argjson pri "${PRIORITY}" \
    '{
        title: $title,
        message: $msg,
        priority: $pri,
        extras: {
            "client::display": {
                contentType: "text/markdown"
            }
        }
    }')

# Send notification to Gotify
curl -s -X POST "${GOTIFY_URL}/message" \
    -H "X-Gotify-Key: ${GOTIFY_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "${PAYLOAD}"