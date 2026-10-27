#!/bin/bash

## https://wiki.servarr.com/sonarr/custom-scripts

# ----------- SONARR CONFIGURATION -----------
SONARR_URL="http://localhost:8989"
SONARR_KEY=""
# --------------------------------------------

# ----------- GOTIFY CONFIGURATION -----------
GOTIFY_URL=""
GOTIFY_TOKEN=""
PRIORITY=5
# --------------------------------------------

## Sonarr Event Types:
# +Test
# +Download - File Import/File Upgrade/Import Complete
#   Import Complete is for batch jobs and does not include Custom Formats.
#   In SeasonPacks, Import Complete will send one notification after the Season is imported.
#       File Import will send a notification for each file imported.
# +SeriesAdd
# +SeriesDelete
# +HealthIssue
# +HealthRestored
# +ApplicationUpdate
# +ManualInteractionRequired

# Fallback values if Sonarr env variables are empty
APP_NAME="${sonarr_instancename:-Sonarr}"
EVENT_TYPE="${sonarr_eventtype:-Test}"
SERIES_ID="${sonarr_series_id}"

SERIES_TITLE="${sonarr_series_title:-Unknown Series}"
SEASON_NUM="${sonarr_episodefile_seasonnumber:-0}"
EPISODE_NUM="${sonarr_episodefile_episodenumbers:-0}"
# Cleanup episode numbers if the file comprises multiple episodes
EPISODE_CLEAN=$(echo "${EPISODE_NUM}" | cut -d',' -f1)

EPISODE_TITLE="${sonarr_episodefile_episodetitles:-TBA}"
QUALITY="${sonarr_episodefile_quality:-Unknown Quality}"
RELEASE_GROUP="${sonarr_episodefile_releasegroup:-Unknown Group}"
CLIENT="${sonarr_download_client:-Unknown Client}"
SERIESPATH="${sonarr_series_path:-Not Available}"

# If the import is a season pack and the episode isn't the first, then exit (to reduce the number of notifications on season pack import)
if [[ "${sonarr_release_releasetype}" == "SeasonPack" && "${EPISODE_CLEAN}" != "1" ]]; then
    exit 0
fi

CUSTOM_FORMATS_RAW="${sonarr_episodefile_customformat:-None}"
CUSTOM_FORMATS="${CUSTOM_FORMATS_RAW//\|/, }"
CUSTOM_FORMAT_SCORE="${sonarr_episodefile_customformatscore:-0}"

# If length of SERIES_ID is zero or if returned false (-1)
if [[ -z "${SERIES_ID}" || "${SERIES_ID}" == "-1" ]]; then
    POSTER_URL="https://www.gstatic.com/android/keyboard/emojikitchen/20260202/u1f44d/u1f44d_u1f422.png" # Thumbs Up Turtle
else # Pull Poster URL from Sonarr using API
    # Fetch series metadata payload
    SONARR_RESPONSE=$(curl -s -H "X-Api-Key: ${SONARR_KEY}" "${SONARR_URL}/api/v3/series/${SERIES_ID}")
    # Extract the poster URL using jq
    POSTER_URL=$(echo "${SONARR_RESPONSE}" | jq -r '.images[] | select(.coverType=="poster") | .remoteUrl')
fi

# Handle Sonarr's Test Event
if [[ "${EVENT_TYPE}" == "Test" ]]; then

    TITLE="${APP_NAME} - Test Successful"
    MESSAGE="
If you are seeing this, **${APP_NAME}** successfully ran the Gotify script!  
![](${POSTER_URL})" 

# Handle Sonarr's Update Event
elif [[ "${EVENT_TYPE}" == "ApplicationUpdate" ]]; then

    TITLE="${APP_NAME} has Updated"
    # If length of sonarr_update_message is zero or if returned false (-1)
    if [[ -z "${sonarr_update_message}" || "${sonarr_update_message}" == "-1" ]]; then
        MESSAGE="
**${APP_NAME}** has updated from *${sonarr_update_previousversion}* to *${sonarr_update_newversion}*  
![](${POSTER_URL})"
    else # Include sonarr_update_message
        MESSAGE="
**${APP_NAME}** has updated from *${sonarr_update_previousversion}* to *${sonarr_update_newversion}*  
***Update Message:*** *${sonarr_update_message}*  
![](${POSTER_URL})"
    fi

# Sonarr Series Added Event
elif [[ "${EVENT_TYPE}" == "SeriesAdd" ]]; then
    TITLE="${APP_NAME} - Series Added"
    MESSAGE="
**Series:** ${SERIES_TITLE}  
**Series Path:** ${SERIESPATH}  
![](${POSTER_URL})"

# Sonarr Series Deleted Event
elif [[ "${EVENT_TYPE}" == "SeriesDelete" ]]; then
    TITLE="${APP_NAME} - Series Deleted"
    MESSAGE="
**Series:** ${SERIES_TITLE}  
**Series Path:** ${SERIESPATH}  
![](${POSTER_URL})"

# Sonarr Import Event, NOT Import Complete
elif [[ "${EVENT_TYPE}" == "Download" ]]; then

    # Improve appearance of upgraded status
    if [[ "${sonarr_isupgrade,,}" == "true" ]]; then
        UPGRADED="Yes"
        if [[ "${sonarr_release_releasetype}" == "SeasonPack" ]]; then
            TITLE="${APP_NAME} - Season Upgrade Complete"
        elif [[ "${sonarr_release_releasetype}" == "SingleEpisode" ]]; then
            TITLE="${APP_NAME} - Episode Upgrade Complete"
        fi
    elif [[ "${sonarr_isupgrade,,}" == "false" ]]; then
        UPGRADED="No"
        if [[ "${sonarr_release_releasetype}" == "SeasonPack" ]]; then
            TITLE="${APP_NAME} - Season Import Complete"
        elif [[ "${sonarr_release_releasetype}" == "SingleEpisode" ]]; then
            TITLE="${APP_NAME} - Episode Import Complete"
        fi
    else
        # Exit if sonarr_isupgrade is NULL
        exit 0
    fi

    # Season Packs
    if [[ "${sonarr_release_releasetype}" == "SeasonPack" ]]; then
        MESSAGE="
**Series:** ${SERIES_TITLE}  
**Season:** ${SEASON_NUM}  
**Released by:** ${RELEASE_GROUP}  
**Quality:** ${QUALITY}  
**Custom Formats:** ${CUSTOM_FORMATS}  
**Release Score:** ${CUSTOM_FORMAT_SCORE}  
![](${POSTER_URL})"

    # Episodes
    elif [[ "${sonarr_release_releasetype}" == "SingleEpisode" ]]; then
        # Pad the season and episode with zeroes
        SXXEXX=$(printf "S%02dE%02d" "${SEASON_NUM}" "${EPISODE_CLEAN}")
        MESSAGE="
**Series:** ${SERIES_TITLE}  
**Episode:** ${SXXEXX}  
**Title:** ${EPISODE_TITLE}  
**Released by:** ${RELEASE_GROUP}  
**Quality:** ${QUALITY}  
**Custom Formats:** ${CUSTOM_FORMATS}  
**Release Score:** ${CUSTOM_FORMAT_SCORE}  
![](${POSTER_URL})"
    fi

elif [[ "${EVENT_TYPE}" == "ManualInteractionRequired" ]]; then

    TITLE="${APP_NAME} - Import Requires Manual Interaction"
    POSTER_URL="https://www.gstatic.com/android/keyboard/emojikitchen/20201001/u1f622/u1f622_u1f422.png" # Sad Turtle
    MESSAGE="
**Series:** ${SERIES_TITLE}  
**Download Client:** ${CLIENT}  
**Download Title:** ${sonarr_download_title}
![](${POSTER_URL})"

elif [[ "${EVENT_TYPE}" == "HealthIssue" ]]; then
    # If ${sonarr_health_issue_type} contains the substring 'Indexer'
    if [[ "${sonarr_health_issue_type}" == *"Indexer"* ]]; then
        # Exit - Prowlarr will take care of indexers
        exit 0
    fi

    POSTER_URL="https://www.gstatic.com/android/keyboard/emojikitchen/20201001/u1f622/u1f622_u1f422.png" # Sad Turtle
    TITLE="${APP_NAME} - Health Degraded"
    MESSAGE="
**Event Level:** ${sonarr_health_issue_level}  
**Event Source:** ${sonarr_health_issue_type}  
**Event Message:** *${sonarr_health_issue_message:-None}*  
**Wiki Link:** ${sonarr_health_issue_wiki:-None}  
![](${POSTER_URL})"

elif [[ "${EVENT_TYPE}" == "HealthRestored" ]]; then
    # If ${sonarr_health_issue_type} contains the substring 'Indexer'
    if [[ "${sonarr_health_restored_type}" == *"Indexer"* ]]; then
        # Exit - Prowlarr will take care of indexers
        exit 0
    fi

    POSTER_URL="https://www.gstatic.com/android/keyboard/emojikitchen/20201001/u1f604/u1f604_u1f422.png" # Happy Turtle
    TITLE="${APP_NAME} - Health Improved"
    MESSAGE="
**Event Level:** ${sonarr_health_restored_level}  
**Event Source:** ${sonarr_health_restored_type}  
**Event Message:** *${sonarr_health_restored_message:-None}*  
**Wiki Link:** ${sonarr_health_restored_wiki:-None}  
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
