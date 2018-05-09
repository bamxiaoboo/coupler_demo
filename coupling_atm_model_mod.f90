module coupling_atm_model_mod

    use CCPL_interface_mod
    
    implicit none
    
    integer, private, parameter           :: RKIND = 4
    integer, private                      :: grid_h2d_id
    integer, public                       :: licom_comp_id
    
contains

    subroutine register_licom_component(comm)

        use CCPL_interface_mod
        integer, intent(inout) :: comm
        licom_comp_id = CCPL_register_component(-1, "licom", "ocn", comm, change_dir=.True., annotation = "register ocn model licom")
    end subroutine register_licom_component
    
    subroutine register_grids_decomps(nlat, nlon, lat, lon)

        use CCPL_interface_mod

        implicit none
        integer, intent(in) :: nlat, nlon
        real(kind=RKIND), intent(in) :: lat(nlat), lon(nlon)

        grid_h2d_id = CCPL_register_H2D_grid_via_global_data(licom_comp_id, "licom_H2D_grid", "LON_LAT", "degrees", "cyclic", nlon, nlat, 0.0, 360.0, -90.0, 90.0, lon, lat, annotation="register gamil H2D grid")
    end subroutine register_grids_decomps

    subroutine register_component_coupling_configuration(time_step, comp_id)

        use CCPL_interface_mod

        implicit none

        integer, intent(inout)       :: comp_id
        character*1024               :: annotation
        integer                      :: time_step

        !----------------register time step to C-Coupler2--------------------------------------
        call CCPL_set_normal_time_step(licom_comp_id, time_step, annotation="setting the time step for licom")

    end subroutine register_component_coupling_configuration

end module coupling_atm_model_mod
