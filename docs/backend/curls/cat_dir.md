# API Documentation for Directory File Concatenation Service

This API provides routes for concatenating files in specified directories into a single JSON object. It supports both predefined directory paths and custom user-specified paths. The files can be of two types: `.json` files, which are parsed and included in the output, or text files, which are read and stored as text in the output.

## Base URL

**Demo URL:**  
`https://4d9b-76-78-246-141.ngrok-free.app`  
*Note: This URL is for demonstration purposes only. It may change or become inactive over time.*

---

## Endpoints

### 1. **Concatenate Files from Predefined Directories**

This endpoint concatenates files from a set of predefined directory paths. Users can select from predefined options.

- **URL**: `/concatenate`
- **Method**: POST
- **Content-Type**: `application/json`
- **Request Body**:

```json
{
  "directory": "app"  // Choose from one of the predefined directories: 'backend', 'app', 'openaudiostandard'
}
```

- **Available Directory Options**:
  - `backend`: `/Users/ebowwa/irl/backend`
  - `app`: `/Users/ebowwa/irl/app`
  - `openaudiostandard`: `/Users/ebowwa/irl/app/IRL/openaudiostandard`

- **Example Request**:

```bash
curl -X POST "https://4d9b-76-78-246-141.ngrok-free.app/concatenate" \
-H "Content-Type: application/json" \
-d '{"directory": "openaudiostandard"}'
```

- **Example Response**:

```json
{
  "config.json": {
    "name": "OpenAudioStandard",
    "version": "1.0.0"
  },
  "readme.txt": "This is a plain text file in the openaudiostandard directory."
}
```

- **Response Description**:
  - The response is a JSON object where each file in the specified directory is represented by its filename as the key. `.json` files are parsed into their respective JSON objects, while non-JSON files are included as plain text.

---

### 2. **Concatenate Files from a Custom Directory Path**

This endpoint allows users to specify a custom directory path. It works similarly to the predefined directory option, but with a user-provided path.

- **URL**: `/concatenate/custom`
- **Method**: POST
- **Content-Type**: `application/json`
- **Request Body**:

```json
{
  "directory_path": "/Users/ebowwa/irl/app/openaudiostandard"  // Full custom directory path
}
```

- **Example Request**:

```bash
curl -X POST "https://95b6-50-247-127-70.ngrok-free.app/concatenate/custom" \
-H "Content-Type: application/json" \
-d '{"directory_path": "/Users/ebowwa/irl/clients/irlap
p/Sources/OpenAudio"}'
```

- **Example Response**:

```json
{
  "config.json": {
    "name": "OpenAudioStandard",
    "version": "1.0.0"
  },
  "readme.txt": "This is a plain text file in the openaudiostandard directory."
}
```

- **Response Description**:
  - The response follows the same structure as the predefined directory endpoint: filenames are keys, with either parsed JSON objects or plain text as the values.

---

### Error Handling

Both endpoints provide informative error messages if issues arise, such as:
- **Invalid Directory Path**: If the provided directory does not exist or is inaccessible, the API returns a `400 Bad Request` with a message like:
  ```json
  {
    "detail": "Invalid directory path"
  }
  ```
- **File Parsing Errors**: If a file cannot be read (for instance, due to improper formatting), the API skips the file and logs an error message in the server log.

---

## How it Works

- **File Types Supported**:
  - `.json` files: These are parsed into JSON objects and included in the final output.
  - Non-JSON files (e.g., `.txt`, `.md`): These are read as plain text and included in the output as strings.

- **Skipped Files**:
  - Files such as `.DS_Store` are automatically skipped and will not be included in the output.

- **Directory Structure**:
  - The API traverses the full directory tree, so any files within subdirectories will also be included in the output. The files are listed at the top-level JSON output, regardless of their depth in the directory.

---

## Example Use Cases

1. **Aggregating JSON Configurations**:
   - Combine multiple JSON configuration files from different parts of your application into a single JSON object for easier processing.

2. **Text File Integration**:
   - Gather multiple readme, log, or plain text files from various subdirectories into one JSON structure for simplified analysis or further processing.

3. **Flexible Directory Processing**:
   - Whether you're working within predefined application directories or need to specify custom paths, the API provides flexible options for gathering and consolidating file contents.

---

## Running the API

To run this API locally or on a remote server:

1. Ensure you have FastAPI and Uvicorn installed:
   ```bash
   pip install fastapi uvicorn
   ```

2. Use `uvicorn` to run the app with hot reloading for development:
   ```bash
   uvicorn backend.route.dev.cat_dir:router --reload
   ```

3. Access the endpoints by sending POST requests to your local server or use the demo URL (`https://4d9b-76-78-246-141.ngrok-free.app`).

Here are the `curl` commands with the `-o` flag added to save the response into a JSON file:

### 1. **Concatenate Files from Predefined Directories** and save to `output_predefined.json`:

```bash
curl -X POST "https://95b6-50-247-127-70.ngrok-free.app/concatenate" \
-H "Content-Type: application/json" \
-d '{"directory": "openaudiostandard"}' \
-o output_predefined.json
```

### 2. **Concatenate Files from a Custom Directory Path** and save to `output_custom.json`:

```bash
curl -X POST "https://95b6-50-247-127-70.ngrok-free.app/concatenate/custom" \
-H "Content-Type: application/json" \
-d '{"directory_path": "/Users/ebowwa/irl/clients/app/irlapp/Sources/OpenAudio"}' \
-o output_custom.json
```

These commands will save the responses into `output_predefined.json` and `output_custom.json` respectively.
