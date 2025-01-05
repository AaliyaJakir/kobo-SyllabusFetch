This Kobo plugin takes Exported Notebooks and generates recommendations for MIT OpenCourses and gets their syllabus content. I use CALIBRE-WEB-AUTOMATED to deliver the syllabus to my Kobo. You can select from a list of exported notebooks, then you get 5 courses to choose from, and then you get a syllabus on your Kobo. 

TO RUN THIS PLUGIN:
1. Put these scripts on your Kobo at /mnt/onboard/
ocw_search.sh
- Takes your search query and searches for courses using vector embedding similarity search
ocw_fetch.sh
- Takes a url and fetches the syllabus content and sends it to Kobo as an epub

2. Run search_service.py and put {EPUB_DIR} where your cwa book ingest folder is

3. Put the KoboRoot.tgz into your .kobo folder and then your Kobo will update (use a cable, ftp w/ nickelmenu, or ssh)

#####

DEVELOPMENT

If you want to make changes and remake the plugin, run this:
```bash
docker run -u $(id -u):$(id -g) --volume="$PWD:$PWD" --entrypoint=make --workdir="$PWD" --env=HOME --rm -it ghcr.io/pgaskin/nickeltc:1 NAME=SyllabusFetch
```

Then use an ftp server to take the KoboRoot.tgz into your .kobo folder

*Note: I host a server on my raspberry pi using search_service.py where I also host my calibre-web-automated
