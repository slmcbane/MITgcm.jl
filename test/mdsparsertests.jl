module MDSParserTests

using Test
using MITgcm.IOFuncs.MDSParser

const goodstring_with_fieldlist_and_otherinfo = """
nDims = [   2 ];
 dimList = [
    90,    1,   90,
  1170,    1, 1170
 ];
 dataprec = [ 'float32' ];
 nrecords = [    9 ];
 timeStepNumber = [       9516 ];
 timeInterval = [  3.162240000000E+07  3.425760000000E+07 ];
 missingValue = [ -9.99000000000000E+02 ];
 nFlds = [  3 ];
 fldList = { 'a' 'b' 'c' };
"""

@testset "MDS parser tests" begin
    metadata = parse_mds_metadata(goodstring_with_fieldlist_and_otherinfo)
    @test metadata.nDims == 2
    @test metadata.dimList == Int[90, 1, 90, 1170, 1, 1170]
    @test metadata.dataprec == "float32"
    @test metadata.nrecords == 9
    @test metadata.nFlds == 3
    @test metadata.fldList == ["a", "b", "c"]
    @test metadata.otherinfo[:timeStepNumber] == 9516
    @test metadata.otherinfo[:timeInterval] == [3.16224e7, 3.42576e7]
    @test metadata == parse_mds_metadata(goodstring_with_fieldlist_and_otherinfo[1:end-1])
end

end #module
