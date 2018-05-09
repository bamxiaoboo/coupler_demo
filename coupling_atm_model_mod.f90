module coupling_atm_model_mod

    use CCPL_interface_mod
    
    implicit none
    
    integer, private, parameter           :: RKIND = 4
    integer, private                      :: decomp_id, grid_h2d_id
    integer, public                       :: licom_comp_id
    real(kind=RKIND), allocatable, public :: psl(:), ts(:), flds(:), fsds(:)    
    
contains

    subroutine register_licom_component(comm)

        use CCPL_interface_mod
        integer, intent(inout) :: comm
        licom_comp_id = CCPL_register_component(-1, "licom", "ocn", comm, change_dir=.True., annotation = "register ocn model licom")
    end subroutine register_licom_component
    
    subroutine register_grids_decomps(nlat, nlon, lat, lon, decomp_size, local_id, npes, local_grid_cell_index)

        use CCPL_interface_mod

        implicit none
        integer, intent(in) :: nlat, nlon
        integer, intent(in) :: decomp_size, local_id, npes
        integer, intent(in) :: local_grid_cell_index(decomp_size, npes)
        real(kind=RKIND), intent(in) :: lat(nlat), lon(nlon)

        grid_h2d_id = CCPL_register_H2D_grid_via_global_data(licom_comp_id, "licom_H2D_grid", "LON_LAT", "degrees", "cyclic", nlon, nlat, 0.0, 360.0, -90.0, 90.0, lon, lat, annotation="register gamil H2D grid")
        decomp_id = CCPL_register_normal_parallel_decomp("decomp_licom_grid", grid_H2D_id, decomp_size, local_grid_cell_index(:,local_id+1), "allocate for licom grid")
    end subroutine register_grids_decomps

    subroutine register_component_coupling_configuration(decomp_size, sst, shf, ssh, mld, &
            time_step, comp_id)

        use CCPL_interface_mod

        implicit none

        integer, intent(in)          :: decomp_size
        real(kind=RKIND), intent(in) :: sst(decomp_size), shf(decomp_size), ssh(decomp_size), mld(decomp_size)
        integer, intent(inout)       :: comp_id
        character*1024               :: annotation
        integer                      :: time_step, timer_id, fields_id(5)
        integer                      :: field_id_psl, field_id_ts, field_id_flds, field_id_fsds
        integer                      :: field_id_sst, field_id_ssh, field_id_shf, field_id_mld

        !----------------register time step to C-Coupler2--------------------------------------
        call CCPL_set_normal_time_step(licom_comp_id, time_step, annotation="setting the time step for licom")
        !----------------register field instances to C-Coupler2--------------------------------
        allocate(psl(decomp_size))
        allocate(ts(decomp_size))
        allocate(flds(decomp_size))
        allocate(fsds(decomp_size))
        field_id_psl = CCPL_register_field_instance(psl(1:decomp_size), "psl", decomp_id, grid_h2d_id, 0, usage_tag=CCPL_TAG_CPL_REST, field_unit="Pa", annotation="register field instance of Sea level pressure") 
        field_id_ts = CCPL_register_field_instance(ts(1:decomp_size), "ts", decomp_id, grid_h2d_id, 0, usage_tag=CCPL_TAG_CPL_REST, field_unit="K", annotation="register field instance of Surface temperature")
        field_id_fsds = CCPL_register_field_instance(fsds(1:decomp_size), "fsds", decomp_id, grid_h2d_id, 0, usage_tag=CCPL_TAG_CPL_REST, field_unit="W/m2", annotation="register field instance of Short wave downward flux at surface")
        field_id_flds  = CCPL_register_field_instance(flds(1:decomp_size), "flds", decomp_id, grid_h2d_id, 0, usage_tag=CCPL_TAG_CPL_REST, field_unit="W/m2", annotation="register field instance of Long wave downward flux at surface")
        field_id_sst  = CCPL_register_field_instance(sst, "sst", decomp_id, grid_h2d_id, 0, usage_tag=CCPL_TAG_CPL_REST, field_unit="C", annotation="register field instance of Sea surface temperature")
        field_id_shf  = CCPL_register_field_instance(shf, "shf", decomp_id, grid_h2d_id, 0, usage_tag=CCPL_TAG_CPL_REST, field_unit="W/m2", annotation="register field instance of Net surface heat flux")
        field_id_ssh = CCPL_register_field_instance(ssh, "ssh", decomp_id, grid_h2d_id, 0, usage_tag=CCPL_TAG_CPL_REST, field_unit="m", annotation="register field instance of Sea surface height")
        field_id_mld = CCPL_register_field_instance(mld, "mld", decomp_id, grid_h2d_id, 0, usage_tag=CCPL_TAG_CPL_REST, field_unit="m", annotation="register field instance of Mixed layer depth")

    end subroutine register_component_coupling_configuration

end module coupling_atm_model_mod
