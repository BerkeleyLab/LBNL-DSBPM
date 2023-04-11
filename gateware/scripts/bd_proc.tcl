proc gen_bd {bd_file project_part project_board ipcore_dirs} {
    # create_ip requires that a project is open in memory. Create project
    # but don't do anything with it
    create_project -in_memory -part $project_part -force my_project

    # specify board_part if existent
    if {$project_board ne "none"} {
        set_property board_part $project_board [current_project]
    }

    # specify additional library directories for custom IPs
    set_property ip_repo_paths $ipcore_dirs [current_fileset]
    update_ip_catalog -rebuild

    # read an BD file into project
    read_bd $bd_file

    # make top level wrapper
    set wrapper_file [make_wrapper -files [get_files $bd_file] -top]

    # add generated file to project
    add_files -norecurse $wrapper_file

    # get BD basename
    set bd_basename [file rootname [file tail $bd_file]]
    # set wrapper to top-level
    set_property TOP ${bd_basename}_wrapper [current_fileset]
    set_property TOP_FILE ${wrapper_file} [current_fileset]

    # Generate all the output products
    generate_target all [get_files $bd_file] -force

    # export and validate hardware platform for use with
    # Vitis
    write_hw_platform -fixed -force $bd_basename.xsa
    validate_hw_platform ./$bd_basename.xsa
}
