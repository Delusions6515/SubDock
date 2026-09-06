if(NOT DEFINED OUTPUT_DIR)
  message(FATAL_ERROR "OUTPUT_DIR is required")
endif()

set(NODE_VERSION "24.15.0")
set(NODE_ARCHIVE "node-v${NODE_VERSION}-linux-x64.tar.xz")
set(NODE_ROOT "node-v${NODE_VERSION}-linux-x64")
set(NODE_SHA256 "472655581fb851559730c48763e0c9d3bc25975c59d518003fc0849d3e4ba0f6")
set(NODE_DIRECTORY "${OUTPUT_DIR}/${NODE_ROOT}")

if(NOT EXISTS "${NODE_DIRECTORY}/bin/node")
  file(MAKE_DIRECTORY "${OUTPUT_DIR}")
  set(archive_path "${OUTPUT_DIR}/${NODE_ARCHIVE}")
  file(DOWNLOAD
    "https://nodejs.org/dist/v${NODE_VERSION}/${NODE_ARCHIVE}"
    "${archive_path}"
    EXPECTED_HASH "SHA256=${NODE_SHA256}"
    TLS_VERIFY ON
    STATUS download_status)
  list(GET download_status 0 download_result)
  if(NOT download_result EQUAL 0)
    list(GET download_status 1 download_error)
    message(FATAL_ERROR "Node.js download failed: ${download_error}")
  endif()
  execute_process(
    COMMAND "${CMAKE_COMMAND}" -E tar xJf "${archive_path}"
    WORKING_DIRECTORY "${OUTPUT_DIR}"
    RESULT_VARIABLE extract_result)
  if(NOT extract_result EQUAL 0 OR NOT EXISTS "${NODE_DIRECTORY}/bin/node")
    message(FATAL_ERROR "Node.js archive extraction failed")
  endif()
endif()
