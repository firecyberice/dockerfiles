checkup.config = {

        "timeframe": 1 * time.Day,
        "refresh_interval": 60,
        "storage": {
                "url": "/checks"
        },
        "status_text": {
                "healthy": "Situation Normal",
                "degraded": "Degraded Service",
                "down": "Service Disruption"
        }
};
