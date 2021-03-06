set(OBJECT_LIBRARY_TARGET_TYPE "OBJECT_LIBRARY")

# Rule which is essentially a wrapper over add_library to compile a set of
# sources to object files.
# Usage:
#     add_object_library(
#       <target_name>
#       HDRS <list of header files>
#       SRCS <list of source files>
#       DEPENDS <list of dependencies>
#       COMPILE_OPTIONS <optional list of special compile options for this target>
function(add_object_library target_name)
  cmake_parse_arguments(
    "ADD_OBJECT"
    "" # No option arguments
    "" # Single value arguments
    "SRCS;HDRS;COMPILE_OPTIONS;DEPENDS" # Multivalue arguments
    ${ARGN}
  )

  if(NOT ADD_OBJECT_SRCS)
    message(FATAL_ERROR "'add_object_library' rule requires SRCS to be specified.")
  endif()

  get_fq_target_name(${target_name} fq_target_name)
  add_library(
    ${fq_target_name}
    OBJECT
    ${ADD_OBJECT_SRCS}
    ${ADD_OBJECT_HDRS}
  )
  target_include_directories(
    ${fq_target_name}
    PRIVATE
      ${LIBC_BUILD_DIR}/include
      ${LIBC_SOURCE_DIR}
      ${LIBC_BUILD_DIR}
  )
  if(ADD_OBJECT_COMPILE_OPTIONS)
    target_compile_options(
      ${fq_target_name}
      PRIVATE ${ADD_OBJECT_COMPILE_OPTIONS}
    )
  endif()

  get_fq_deps_list(fq_deps_list ${ADD_OBJECT_DEPENDS})
  if(fq_deps_list)
    add_dependencies(${fq_target_name} ${fq_deps_list})
  endif()

  set_target_properties(
    ${fq_target_name}
    PROPERTIES
      "TARGET_TYPE" ${OBJECT_LIBRARY_TARGET_TYPE}
      "OBJECT_FILES" "$<TARGET_OBJECTS:${fq_target_name}>"
      "DEPS" "${fq_deps_list}"
  )
endfunction(add_object_library)

set(ENTRYPOINT_OBJ_TARGET_TYPE "ENTRYPOINT_OBJ")

# A rule for entrypoint object targets.
# Usage:
#     add_entrypoint_object(
#       <target_name>
#       [ALIAS|REDIRECTED] # Specified if the entrypoint is redirected or an alias.
#       [NAME] <the C name of the entrypoint if different from target_name>
#       SRCS <list of .cpp files>
#       HDRS <list of .h files>
#       DEPENDS <list of dependencies>
#       COMPILE_OPTIONS <optional list of special compile options for this target>
#       SPECIAL_OBJECTS <optional list of special object targets added by the rule `add_object`>
#     )
function(add_entrypoint_object target_name)
  cmake_parse_arguments(
    "ADD_ENTRYPOINT_OBJ"
    "ALIAS;REDIRECTED" # Optional argument
    "NAME" # Single value arguments
    "SRCS;HDRS;DEPENDS;COMPILE_OPTIONS"  # Multi value arguments
    ${ARGN}
  )

  get_fq_target_name(${target_name} fq_target_name)

  if(ADD_ENTRYPOINT_OBJ_ALIAS)
    # Alias targets help one add aliases to other entrypoint object targets.
    # One can use alias targets setup OS/machine independent entrypoint targets.
    list(LENGTH ADD_ENTRYPOINT_OBJ_DEPENDS deps_size)
    if(NOT (${deps_size} EQUAL "1"))
      message(FATAL_ERROR "An entrypoint alias should have exactly one dependency.")
    endif()
    list(GET ADD_ENTRYPOINT_OBJ_DEPENDS 0 dep_target)
    get_fq_dep_name(fq_dep_name ${dep_target})
    if(NOT TARGET ${fq_dep_name})
      message(WARNING "Aliasee ${fq_dep_name} for entrypoint alias ${target_name} missing; "
                      "Target ${target_name} will be ignored.")
      return()
    endif()

    get_target_property(obj_type ${fq_dep_name} "TARGET_TYPE")
    if((NOT obj_type) OR (NOT (${obj_type} STREQUAL ${ENTRYPOINT_OBJ_TARGET_TYPE})))
      message(FATAL_ERROR "The aliasee of an entrypoint alias should be an entrypoint.")
    endif()

    add_custom_target(${fq_target_name})
    add_dependencies(${fq_target_name} ${fq_dep_name})
    get_target_property(object_file ${fq_dep_name} "OBJECT_FILE")
    get_target_property(object_file_raw ${fq_dep_name} "OBJECT_FILE_RAW")
    set_target_properties(
      ${fq_target_name}
      PROPERTIES
        "TARGET_TYPE" ${ENTRYPOINT_OBJ_TARGET_TYPE}
        "IS_ALIAS" "YES"
        "OBJECT_FILE" ""
        "OBJECT_FILE_RAW" ""
        "DEPS" "${fq_dep_name}"
    )
    return()
  endif()

  if(NOT ADD_ENTRYPOINT_OBJ_SRCS)
    message(FATAL_ERROR "`add_entrypoint_object` rule requires SRCS to be specified.")
  endif()
  if(NOT ADD_ENTRYPOINT_OBJ_HDRS)
    message(FATAL_ERROR "`add_entrypoint_object` rule requires HDRS to be specified.")
  endif()

  set(entrypoint_name ${target_name})
  if(ADD_ENTRYPOINT_OBJ_NAME)
    set(entrypoint_name ${ADD_ENTRYPOINT_OBJ_NAME})
  endif()

  set(objects_target_name "${fq_target_name}_objects")

  add_library(
    ${objects_target_name}
    # We want an object library as the objects will eventually get packaged into
    # an archive (like libc.a).
    OBJECT
    ${ADD_ENTRYPOINT_OBJ_SRCS}
    ${ADD_ENTRYPOINT_OBJ_HDRS}
  )
  target_compile_options(
    ${objects_target_name}
    BEFORE
    PRIVATE
      -fpie ${LLVM_CXX_STD_default} -ffreestanding
  )
  target_include_directories(
    ${objects_target_name}
    PRIVATE
      ${LIBC_BUILD_DIR}/include
      ${LIBC_SOURCE_DIR}
      ${LIBC_BUILD_DIR}
  )
  get_fq_deps_list(fq_deps_list ${ADD_ENTRYPOINT_OBJ_DEPENDS})
  add_dependencies(
    ${objects_target_name}
    libc.src.__support.common
    ${fq_deps_list}
  )

  if(ADD_ENTRYPOINT_OBJ_COMPILE_OPTIONS)
    target_compile_options(
      ${objects_target_name}
      PRIVATE ${ADD_ENTRYPOINT_OBJ_COMPILE_OPTIONS}
    )
  endif()

  set(object_file_raw "${CMAKE_CURRENT_BINARY_DIR}/${target_name}_raw.o")
  set(object_file "${CMAKE_CURRENT_BINARY_DIR}/${target_name}.o")

  set(input_objects $<TARGET_OBJECTS:${objects_target_name}>)
  add_custom_command(
    OUTPUT ${object_file_raw}
    DEPENDS ${input_objects}
    COMMAND ${CMAKE_LINKER} -r ${input_objects} -o ${object_file_raw}
  )

  set(alias_attributes "0,function,global")
  if(ADD_ENTRYPOINT_OBJ_REDIRECTED)
    set(alias_attributes "${alias_attributes},hidden")
  endif()

  add_custom_command(
    OUTPUT ${object_file}
    # We llvm-objcopy here as GNU-binutils objcopy does not support the 'hidden' flag.
    DEPENDS ${object_file_raw} ${llvm-objcopy}
    COMMAND $<TARGET_FILE:llvm-objcopy> --add-symbol
            "${entrypoint_name}=.llvm.libc.entrypoint.${entrypoint_name}:${alias_attributes}"
            ${object_file_raw} ${object_file}
  )

  add_custom_target(
    ${fq_target_name}
    ALL
    DEPENDS ${object_file}
  )
  set_target_properties(
    ${fq_target_name}
    PROPERTIES
      "TARGET_TYPE" ${ENTRYPOINT_OBJ_TARGET_TYPE}
      "OBJECT_FILE" "${object_file}"
      "OBJECT_FILE_RAW" "${object_file_raw}"
      "DEPS" "${fq_deps_list}"
  )

  if(LLVM_LIBC_ENABLE_LINTING)
    set(lint_timestamp "${CMAKE_CURRENT_BINARY_DIR}/.${target_name}.__lint_timestamp__")

    add_custom_command(
      OUTPUT ${lint_timestamp}
      # --quiet is used to surpress warning statistics from clang-tidy like:
      #     Suppressed X warnings (X in non-user code).
      # There seems to be a bug in clang-tidy where by even with --quiet some
      # messages from clang's own diagnostics engine leak through:
      #     X warnings generated.
      # Until this is fixed upstream, we use -fno-caret-diagnostics to surpress
      # these.
      COMMAND $<TARGET_FILE:clang-tidy>
              "--extra-arg=-fno-caret-diagnostics" --quiet
              # Path to directory containing compile_commands.json
              -p ${PROJECT_BINARY_DIR}
              ${ADD_ENTRYPOINT_OBJ_SRCS}
      # We run restrict-system-libc-headers with --system-headers to prevent
      # transitive inclusion through compler provided headers.
      COMMAND $<TARGET_FILE:clang-tidy> --system-headers
              --checks="-*,llvmlibc-restrict-system-libc-headers"
              --quiet
              -p ${PROJECT_BINARY_DIR}
              ${ADD_ENTRYPOINT_OBJ_SRCS}
      # We have two options for running commands, add_custom_command and
      # add_custom_target. We don't want to run the linter unless source files
      # have changed. add_custom_target explicitly runs everytime therefore we
      # use add_custom_command. This function requires an output file and since
      # linting doesn't produce a file, we create a dummy file using a
      # crossplatform touch.
      COMMAND "${CMAKE_COMMAND}" -E touch ${lint_timestamp}
      COMMENT "Linting... ${target_name}"
      DEPENDS ${clang-tidy} ${objects_target_name} ${ADD_ENTRYPOINT_OBJ_SRCS}
      WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    )

    add_custom_target(${fq_target_name}.__lint__
      DEPENDS ${lint_timestamp})
    add_dependencies(lint-libc ${fq_target_name}.__lint__)
    add_dependencies(${fq_target_name} ${fq_target_name}.__lint__)
  endif()

endfunction(add_entrypoint_object)

# Rule build a redirector object file.
function(add_redirector_object target_name)
  cmake_parse_arguments(
    "REDIRECTOR_OBJECT"
    "" # No optional arguments
    "SRC" # The cpp file in which the redirector is defined.
    "" # No multivalue arguments
    ${ARGN}
  )
  if(NOT REDIRECTOR_OBJECT_SRC)
    message(FATAL_ERROR "'add_redirector_object' rule requires SRC option listing one source file.")
  endif()

  add_library(
    ${target_name}
    OBJECT
    ${REDIRECTOR_OBJECT_SRC}
  )
  target_compile_options(
    ${target_name}
    BEFORE PRIVATE -fPIC
  )
endfunction(add_redirector_object)
