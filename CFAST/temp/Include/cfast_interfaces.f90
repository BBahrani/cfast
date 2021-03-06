
! --------------------------- interfaces -------------------------------------------

module  interfaces
    interface
    subroutine chemie (pyrolysis_rate, molar_mass, entrainment_rate, source_room, h_c, y_soot, y_co, & 
    n_C, n_H, n_O, n_N, n_Cl, source_o2, lower_o2_limit, activated_room, activated_sprinkler, activated_time, &
    activated_rate, model_time, hrr_at_activation, hrr_constrained, pyrolysis_rate_constrained, species_rates)

    use precision_parameters

    integer, intent(in) :: source_room, activated_room, activated_sprinkler
    real(eb), intent(in) :: pyrolysis_rate, molar_mass, entrainment_rate, h_c, y_soot, y_co, &
    n_C, n_H, n_O, n_N, n_Cl, source_o2, lower_o2_limit, activated_time, activated_rate, model_time
    real(eb), intent(out) :: hrr_constrained, hrr_at_activation, pyrolysis_rate_constrained, species_rates(:)
    end subroutine chemie
end interface
end module interfaces