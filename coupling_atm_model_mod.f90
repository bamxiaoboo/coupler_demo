module coupling_atm_model_mod

    use CCPL_interface_mod
    
    implicit none
    
    integer, private, parameter           :: RKIND = 4
    integer, public                       :: licom_comp_id
    
contains

    subroutine register_licom_component(comm)

        use CCPL_interface_mod
        integer, intent(inout) :: comm
        licom_comp_id = CCPL_register_component(-1, "licom", "ocn", comm, change_dir=.True., annotation = "register ocn model licom")
    end subroutine register_licom_component
    
end module coupling_atm_model_mod
