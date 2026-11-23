# Glossary

**Count**: the number of devices a board saw often enough during one scan cycle; the system's estimate of how many people are in the room. A count of 0 means the room was empty.

**Offline hour**: an hour with no count at all because the board sent nothing. Never the same as a count of 0.

**Actual**: the counts that were really measured for an hour (averaged over that hour).

**Prediction**: what an hour is expected to look like, built only from the same hour on the same weekday in the previous 1–4 weeks. Offline hours in those weeks are left out, not counted as 0.

**Typical range**: the lowest to highest hourly count among the weeks a prediction is built from.

**Usual count**: the average of those weeks' hourly counts (the prediction's mean).

**Weeks of history**: how many of the previous 4 weeks actually had data for that hour (0–4). With 0 there is no prediction.

**Core hours**: the part of the day being looked at: either 6:00–23:00 or the full day.

**Week heatmap**: weekdays × core hours, each cell showing the usual count for that weekday and hour over the coming 7 days.
