#!/usr/bin/env python3
import os
import logging
# Added for newer werkzeug versions
import werkzeug
from robobrowser import RoboBrowser
werkzeug.cached_property = werkzeug.utils.cached_property


def grab_keys(get_keys):
    if not get_keys:
        return False
    logging.info("Getting MakeMKV hashed keys for UHD rips")
    br = RoboBrowser()
    br.open('https://makemkv.com/forum2/viewtopic.php?f=12&t=16959')
    page_str = str(br.parsed())
    i = 1

    def get_key_link(base_link):
        global i, page_str
        beg = page_str.find(base_link)
        str_length = len(base_link)

        while True:
            link = page_str[beg:beg + str_length + i]
            print(link)

            if page_str[beg + str_length:beg + str_length + i].isnumeric() is False:
                return link[:-1]
                i = i + 1

        # print(get_key_link())
        os.system('tinydownload -o keys_hashed.txt ' + get_key_link('https://s000.tinyupload.com/index.php?file_id='))
        br.open('https://forum.doom9.org/showthread.php?t=175194')
        page_str = str(br.parsed())
        i = 1
        os.system('tinydownload -o KEYDB.cfg ' + get_key_link('https://s000.tinyupload.com/index.php?file_id='))
        os.system('mv -u -t /home/arm/.MakeMKV keys_hashed.txt KEYDB.cfg')
