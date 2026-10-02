#!/bin/bash

## https://wiki.servarr.com/radarr/custom-scripts

# ----------- RADARR CONFIGURATION -----------
RADARR_URL="http://localhost:7878"
RADARR_KEY=""
# --------------------------------------------

# ----------- GOTIFY CONFIGURATION -----------
GOTIFY_URL=""
GOTIFY_TOKEN=""
PRIORITY=5
# --------------------------------------------

## Radarr Event Types:
# +Test
# +Download - Movie File Import/Movie File Upgrade
# +MovieAdded
# +MovieDelete
# +HealthIssue
# +HealthRestored
# +ApplicationUpdate
# +ManualInteractionRequired

# Fallback values if Radarr env variables are empty
APP_NAME="${radarr_instancename:-Radarr}"
EVENT_TYPE="${radarr_eventtype:-Test}"
MOVIE_ID="${radarr_movie_id}"

MOVIE_TITLE="${radarr_movie_title:-Unknown Movie}"
MOVIE_YEAR="${radarr_movie_year:-0000}"
QUALITY="${radarr_moviefile_quality:-Unknown Quality}"
RELEASE_GROUP="${radarr_moviefile_releasegroup:-Unknown Group}"
CLIENT="${radarr_download_client:-Unknown Client}"
MOVIEPATH="${radarr_movie_path:-Not Available}"

CUSTOM_FORMATS_RAW="${radarr_moviefile_customformat:-None}"
CUSTOM_FORMATS="${CUSTOM_FORMATS_RAW//\|/, }"
CUSTOM_FORMAT_SCORE="${radarr_moviefile_customformatscore:-0}"

# If length of MOVIE_ID is zero or if returned false (-1)
if [[ -z "${MOVIE_ID}" || "${MOVIE_ID}" == "-1" ]]; then
    POSTER_URL="https://www.gstatic.com/android/keyboard/emojikitchen/20260202/u1f44d/u1f44d_u1f422.png" # Thumbs Up Turtle
else # Pull Poster URL from Radarr using API
    # Fetch movie metadata payload
    RADARR_RESPONSE=$(curl -s -H "X-Api-Key: ${RADARR_KEY}" "${RADARR_URL}/api/v3/movie/${MOVIE_ID}")
    # Extract the poster URL using jq
    POSTER_URL=$(echo "${RADARR_RESPONSE}" | jq -r '.images[] | select(.coverType=="poster") | .remoteUrl')
fi

# Handle Radarr's Test Event
if [[ "${EVENT_TYPE}" == "Test" ]]; then

    TITLE="${APP_NAME} - Test Successful"
    MESSAGE="
If you are seeing this, **${APP_NAME}** successfully ran the Gotify script!  
![](${POSTER_URL})" 

# Handle Radarr's Update Event
elif [[ "${EVENT_TYPE}" == "ApplicationUpdate" ]]; then

    TITLE="${APP_NAME} has Updated"
    # If length of radarr_update_message is zero or if returned false (-1)
    if [[ -z "${radarr_update_message}" || "${radarr_update_message}" == "-1" ]]; then
        MESSAGE="
**${APP_NAME}** has updated from *${radarr_update_previousversion}* to *${radarr_update_newversion}*  
![](${POSTER_URL})"
    else # Include radarr_update_message
        MESSAGE="
**${APP_NAME}** has updated from *${radarr_update_previousversion}* to *${radarr_update_newversion}*  
***Update Message:*** *${radarr_update_message}*  
![](${POSTER_URL})"
    fi

# Radarr Movie Added Event
elif [[ "${EVENT_TYPE}" == "MovieAdded" ]]; then
    TITLE="${APP_NAME} - Movie Added"
    MESSAGE="
**Movie:** ${MOVIE_TITLE} (${MOVIE_YEAR})  
**Movie Path:** ${MOVIEPATH}  
![](${POSTER_URL})"

# Radarr Movie Deleted Event
elif [[ "${EVENT_TYPE}" == "MovieDelete" ]]; then
    TITLE="${APP_NAME} - Movie Deleted"
    MESSAGE="
**Movie:** ${MOVIE_TITLE} (${MOVIE_YEAR})  
**Movie Path:** ${MOVIEPATH}  
![](${POSTER_URL})"

# Radarr Import / Upgrade Event
elif [[ "${EVENT_TYPE}" == "Download" ]]; then

    # Improve appearance of upgraded status
    if [[ "${radarr_isupgrade,,}" == "true" ]]; then
        UPGRADED="Yes"
        TITLE="${APP_NAME} - Movie Upgrade Complete"
    elif [[ "${radarr_isupgrade,,}" == "false" ]]; then
        UPGRADED="No"
        TITLE="${APP_NAME} - Movie Import Complete"
    else
        # Exit if radarr_isupgrade is NULL
        exit 0
    fi

    MESSAGE="
**Movie:** ${MOVIE_TITLE} (${MOVIE_YEAR})  
**Released by:** ${RELEASE_GROUP}  
**Quality:** ${QUALITY}  
**Custom Formats:** ${CUSTOM_FORMATS}  
**Release Score:** ${CUSTOM_FORMAT_SCORE}  
![](${POSTER_URL})"

# Radarr Manual Interaction Required Event
elif [[ "${EVENT_TYPE}" == "ManualInteractionRequired" ]]; then

    TITLE="${APP_NAME} - Import Requires Manual Interaction"
    POSTER_URL="https://www.gstatic.com/android/keyboard/emojikitchen/20201001/u1f622/u1f622_u1f422.png" # Sad Turtle
    MESSAGE="
**Movie:** ${MOVIE_TITLE} (${MOVIE_YEAR})  
**Download Client:** ${CLIENT}  
**Download Title:** ${radarr_download_title}
![](${POSTER_URL})"

elif [[ "${EVENT_TYPE}" == "HealthIssue" ]]; then
    POSTER_URL="https://www.gstatic.com/android/keyboard/emojikitchen/20201001/u1f622/u1f622_u1f422.png" # Sad Turtle
    TITLE="${APP_NAME} - Health Degraded"
    MESSAGE="
**Event Level:** ${radarr_health_issue_level}  
**Event Source:** ${radarr_health_issue_type}  
**Event Message:** *${radarr_health_issue_message:-None}*  
**Wiki Link:** ${radarr_health_issue_wiki:-None}  
![](${POSTER_URL})"

elif [[ "${EVENT_TYPE}" == "HealthRestored" ]]; then
    POSTER_URL="https://www.gstatic.com/android/keyboard/emojikitchen/20201001/u1f604/u1f604_u1f422.png" # Happy Turtle
    TITLE="${APP_NAME} - Health Improved"
    MESSAGE="
**Event Level:** ${radarr_health_restored_level}  
**Event Source:** ${radarr_health_restored_type}  
**Event Message:** *${radarr_health_restored_message:-None}*  
**Wiki Link:** ${radarr_health_restored_wiki:-None}  
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