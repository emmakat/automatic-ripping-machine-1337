#!/usr/bin/env python3

# set up logging

import os
import logging
import time

from arm.config.config import cfg
from arm.ripper import music_brainz


def identify_audio_cd(job):
    """
    Get the title for audio cds to use for the logfile name.
    Needs the job class passed into it so it can be forwarded to mb
    return - only the logfile - setup_logging() adds the full path
    """
    # Use the music label if we can find it - defaults to music_cd.log
    disc_id = music_brainz.get_disc_id(job)
    mb_title = music_brainz.get_title(disc_id, job)
    if mb_title == "not identified":
        job.label = job.title = "not identified"
        logfile = "music_cd.log"
        new_log_file = f"music_cd_{round(time.time() * 100)}.log"
    else:
        logfile = f"{mb_title}.log"
        new_log_file = f"{mb_title}_{round(time.time() * 100)}.log"

    temp_log_full = os.path.join(cfg['LOGPATH'], logfile)
    logfile = new_log_file if os.path.isfile(temp_log_full) else logfile
    return logfile


def setup_logging(job):
    """Setup logging and return the path to the logfile for
    redirection of external calls
    We need to return the full logfile path but set the job.logfile to just the filename
    """
    # This isn't catching all of them
    if job.label == "" or job.label is None:
        if job.disctype == "music":
            logfile = job.logfile = identify_audio_cd(job)
        else:
            logfile = "empty.log"
        # set a logfull for empty.log and music_cd.log
        logfull = os.path.join(cfg['LOGPATH'], logfile)
    else:
        logfile = job.label + ".log"
        new_log_file = f"{job.label}_{round(time.time() * 100)}.log"
        temp_log_full = os.path.join(cfg['LOGPATH'], logfile)
        logfile = new_log_file if os.path.isfile(temp_log_full) else logfile
        # If log already exist use the new_log_file
        logfull = os.path.join(cfg['LOGPATH'], new_log_file) if os.path.isfile(temp_log_full) \
            else os.path.join(cfg['LOGPATH'], str(job.label) + ".log")
        job.logfile = logfile
    # Remove all handlers associated with the root logger object.
    for handler in logging.root.handlers[:]:
        logging.root.removeHandler(handler)
    # Debug formatting
    if cfg['LOGLEVEL'] == "DEBUG":
        logging.basicConfig(filename=logfull,
                            format='[%(asctime)s] %(levelname)s ARM: %(module)s.%(funcName)s %(message)s',
                            datefmt=cfg['DATE_FORMAT'], level=cfg['LOGLEVEL'])
    else:
        logging.basicConfig(filename=logfull,
                            format='[%(asctime)s] %(levelname)s ARM: %(message)s',
                            datefmt=cfg['DATE_FORMAT'], level=cfg['LOGLEVEL'])

    # This stops apprise spitting our secret keys when users posts online
    logging.getLogger("apprise").setLevel(logging.WARN)
    logging.getLogger("requests").setLevel(logging.WARN)
    logging.getLogger("urllib3").setLevel(logging.WARN)

    # Return the full logfile location to the logs
    return logfull


def clean_up_logs(logpath, loglife):
    """Delete all log files older than x days\n
    logpath = path of log files\n
    loglife = days to let logs live\n

    """
    if loglife < 1:
        logging.info("loglife is set to 0. Removal of logs is disabled")
        return False
    now = time.time()
    logging.info(f"Looking for log files older than {loglife} days old.")

    for filename in os.listdir(logpath):
        fullname = os.path.join(logpath, filename)
        if fullname.endswith(".log") and os.stat(fullname).st_mtime < now - loglife * 86400:
            logging.info(f"Deleting log file: {filename}")
            os.remove(fullname)
