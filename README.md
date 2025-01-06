# Kobo-SyllabusFetch

This Kobo plugin takes exported notebooks and generates recommendations for MIT OpenCourses, fetching their syllabus content. Using **CALIBRE-WEB-AUTOMATED**, the syllabus is delivered directly to your Kobo. 

## How It Works
1. Select an exported notebook on your Kobo.
2. Get 5 recommended MIT OpenCourses.
3. Fetch the syllabus and receive it as an EPUB on your Kobo.

---

## Installation

1. **Add Scripts to Kobo**  
   Place these scripts in `/mnt/onboard/.adds/syllabusFetch/`:
   - `ocw_search.sh`: Searches courses using vector embedding similarity.
   - `ocw_fetch.sh`: Fetches syllabus content and sends it to Kobo as an EPUB.

2. **Run endpoint to send books to Kobo using Calibre-kobo server**  
   Run `calibre_kobo_server.py` as your server and configure `{EPUB_DIR}` to point to your `calibre-web-automated` book ingestion folder.

3. **Configure Server URL**  
   Add your server URL to `/mnt/onboard/.adds/pkm/.env`:
   ```bash
   SERVER_URL=http://your-server-address:port
   ```
   This should point to where your `calibre_kobo_server.py` is running.

4. **Update Kobo**  
   Place `KoboRoot.tgz` in your Kobo’s `.kobo` folder. This will update your Kobo.

---

## Development

To make changes and rebuild the plugin:
```bash
docker run -u $(id -u):$(id -g) --volume="$PWD:$PWD" --entrypoint=make --workdir="$PWD" --env=HOME --rm -it ghcr.io/pgaskin/nickeltc:1 NAME=SyllabusFetch
