using TestItems

@testitem "Package loads" begin
    using SGM

    @test SGM isa Module
end
