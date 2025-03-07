require 'rubygems'
require 'minitest/autorun'
require 'minitest/spec' # must be after "require 'minitest/autorun'" to avoid a 'circular require considered harmful' warning

require File.expand_path(File.dirname(__FILE__)) + '/../lib/timecode'

# Needed for a number of tests from the past
Timecode.add_custom_framerate!(10)
Timecode.add_custom_framerate!(12.5)
Timecode.add_custom_framerate!(57)
Timecode.add_custom_framerate!(45)
Timecode.add_custom_framerate!(12)


describe "Timecode.new should" do

  it "instantiate from int" do
    tc = Timecode.new(10)
    _(tc).must_be_kind_of Timecode
    _(tc.total).must_equal 10
  end

  it "always coerce FPS to float" do
    _(Timecode.new(10, 24).fps).must_be_kind_of(Float)
    _(Timecode.new(10, 25.0).fps).must_be_kind_of(Float)
    _(Timecode.new(10, 29.97).fps).must_be_kind_of(Float)
    _(Timecode.new(10, 59.94).fps).must_be_kind_of(Float)
  end

  it "create a zero TC with no arguments" do
    _(Timecode.new).must_equal Timecode.new(0)
  end

  it "accept full string SMPTE timecode as well" do
    _(Timecode.new("00:25:30:10", 25)).must_equal Timecode.parse("00:25:30:10")
  end

  it 'calculates correctly (spot check with special values)' do
    _(lambda{ Timecode.new 496159, 23.976 }).must_be_silent
    _(lambda{ Timecode.new 548999, 23.976 }).must_be_silent
    _(lambda{ Timecode.new 9662, 29.97 }).must_be_silent
  end

  it 'calculates seconds correctly for rational fps' do
    _(Timecode.new(548999, 24).seconds).must_equal 14
    _(Timecode.new(548999, 23.976).seconds).must_equal 37
    _(Timecode.new(9662, 29.97, true).seconds).must_equal 22
    _(Timecode.new(1078920, 29.97, true).seconds).must_equal 0
  end

  it 'calculates timecode correctly for rational fps' do
    atoms_ok = lambda { |tc, h, m, s, f|
        _(tc.hours).must_equal h
        _(tc.minutes).must_equal m
        _(tc.seconds).must_equal s
        _(tc.frames).must_equal f
      }

    atoms_ok.call(Timecode.new(9662, 29.97, true), 0, 5, 22, 12)
    atoms_ok.call(Timecode.new(467637, 29.97, true), 4, 20, 3, 15)
    atoms_ok.call(Timecode.new(1078920, 29.97, true), 10, 0, 0, 0)
  end
end

describe "Timecode.validate_atoms! should" do

  it "disallow more than 999 hrs" do
    _(lambda{ Timecode.validate_atoms!(999,0,0,0, 25) }).must_be_silent
    _(lambda{ Timecode.validate_atoms!(1000,0,0,0, 25) }).must_raise(Timecode::RangeError)
  end

  it "disallow more than 59 minutes" do
    _(lambda{ Timecode.validate_atoms!(1,60,0,0, 25) }).must_raise(Timecode::RangeError)
  end

  it "disallow more than 59 seconds" do
    _(lambda{ Timecode.validate_atoms!(1,0,60,0, 25) }).must_raise(Timecode::RangeError)
  end

  it "disallow more frames than what the framerate permits" do
    _(lambda{ Timecode.validate_atoms!(1,0,45,25, 25) }).must_raise(Timecode::RangeError)
    _(lambda{ Timecode.validate_atoms!(1,0,45,32, 30) }).must_raise(Timecode::RangeError)
  end

  it "pass validation with usable values" do
    _(lambda{ Timecode.validate_atoms!(20, 20, 10, 5, 25)}).must_be_silent
  end
end

describe "Timecode.at should" do

  it "disallow more than 999 hrs" do
    _(lambda{ Timecode.at(999,0,0,0) }).must_be_silent
    _(lambda{ Timecode.at(1000,0,0,0) }).must_raise(Timecode::RangeError)
  end

  it "disallow more than 59 minutes" do
    _(lambda{ Timecode.at(1,60,0,0) }).must_raise(Timecode::RangeError)
  end

  it "disallow more than 59 seconds" do
    _(lambda{ Timecode.at(1,0,60,0) }).must_raise(Timecode::RangeError)
  end

  it "disallow more frames than what the framerate permits" do
    _(lambda{ Timecode.at(1,0,60,25, 25) }).must_raise(Timecode::RangeError)
    _(lambda{ Timecode.at(1,0,60,32, 30) }).must_raise(Timecode::RangeError)
  end

  it "properly accept usable values" do
    _(Timecode.at(20, 20, 10, 5).to_s).must_equal "20:20:10:05"
  end
end

describe "A new Timecode object should" do
  it "be frozen" do
    # must_be :frozen? is somehow dead too
    assert Timecode.new(10).frozen?
  end
end

describe "An existing Timecode should" do

  before do
    @five_seconds = Timecode.new(5*25, 25)
    @one_and_a_half_film = (90 * 60) * 24
    @film_tc = Timecode.new(@one_and_a_half_film, 24)
  end

  it "report that the framerates are in delta" do
    tc = Timecode.new(1)
    _(tc.framerate_in_delta(25.0000000000000001, 25.0000000000000003)).must_equal(true)
  end

  it "validate equality based on delta" do
    t1, t2 = Timecode.new(10, 25.0000000000000000000000000001), Timecode.new(10, 25.0000000000000000000000000002)
    _(t1).must_equal(t2)
  end

  it "report total as it's to_i" do
    _(Timecode.new(10).to_i).must_equal(10)
  end

  it "coerce itself to int" do
    _((10 + Timecode.new(2))).must_equal 12
  end

  it "support hours" do
    _(@five_seconds).must_respond_to :hours
    _(@five_seconds.hours).must_equal 0
    _(@film_tc.hours).must_equal 1
  end

  it "support minutes" do
    _(@five_seconds).must_respond_to :minutes
    _(@five_seconds.minutes).must_equal 0
    _(@film_tc.minutes).must_equal 30
  end

  it "support seconds" do
    _(@five_seconds).must_respond_to :seconds
    _(@five_seconds.seconds).must_equal 5
    _(@film_tc.seconds).must_equal 0
  end

  it "support frames" do
    _(@film_tc.frames).must_equal 0
  end

  it "report frame_interval as a float" do
    tc = Timecode.new(10)
    _(tc).must_respond_to :frame_interval

    _(tc.frame_interval).must_be_within_delta 0.04, 0.0001
    tc = Timecode.new(10, 30)
    _(tc.frame_interval).must_be_within_delta 0.03333, 0.0001
  end

  it "be comparable" do
    _((Timecode.new(10) < Timecode.new(9))).must_equal false
    _((Timecode.new(9) < Timecode.new(10))).must_equal true
    _(Timecode.new(9)).must_equal Timecode.new(9)
  end

  it "raise on comparison of incompatible timecodes" do
    _(lambda { Timecode.new(10, 10) < Timecode.new(10, 20)}).must_raise(Timecode::WrongFramerate)
  end
end

#module MiniTest::Assertions
#  UNDEFINED = MiniTest::Assertions::UNDEFINED
#  def assert_operator o1, op, o2 = UNDEFINED, msg = nil
#    puts [o1, op, o2, msg].inspect
#    return assert_predicate o1, op, msg if UNDEFINED == o2
#    msg = message(msg) { "Expected #{mu_pp(o1)} to be #{op} #{mu_pp(o2)}" }
#    assert o1.__send__(op, o2), msg
#  end
#end

describe "A Timecode of zero should" do
  it "properly respond to zero?" do
    _(Timecode.new(0)).must_respond_to :zero?
    # must_be :zero? is somehow broken
    assert Timecode.new(0).zero?
    refute Timecode.new(1).zero?
  end
end

describe "Timecode.from_seconds should" do
  it "properly process this specific case for a float framerate" do
    float_secs = 89.99165971643036
    float_fps = 23.9898
    Timecode.add_custom_framerate!(float_fps)
    _(lambda{ Timecode.from_seconds(float_secs, float_fps) }).must_be_silent
  end

  it "properly process a DF framerate" do
    _(Timecode.from_seconds(322.4004, 29.97, true).to_i).must_equal 9662
    _(Timecode.from_seconds(600.0, 29.97, true).to_i).must_equal 17982
    _(Timecode.from_seconds(15603.5005, 29.97, true).to_i).must_equal 467637
    _(Timecode.from_seconds(36000.0, 29.97, true).to_i).must_equal 1078920
  end
end

describe "Timecode#to_seconds should" do
  it "return a float" do
    _(Timecode.new(0).to_seconds).must_be_kind_of Float
  end

  it "return the value in seconds" do
    fps = 24
    secs = 126.3
    _(Timecode.new(fps * secs, fps).to_seconds).must_be_within_delta 126.3, 0.1
  end

  it "properly roundtrip a value via Timecode.from_seconds" do
    secs_in = 19.76
    from_secs = Timecode.from_seconds(secs_in, 25.0)
    _(from_secs.total).must_be_within_delta 494, 0.001
    _(from_secs.to_seconds).must_be_within_delta secs_in, 0.001

    secs_in = 15603.50
    from_secs = Timecode.from_seconds(secs_in, 29.97, true)
    _(from_secs.total).must_be_within_delta 467637, 0.001
    _(from_secs.to_seconds).must_be_within_delta secs_in, 0.005
  end
end

describe "An existing Timecode on inspection should" do
  it "properly present himself via inspect" do
    _(Timecode.new(10, 25).inspect).must_equal "#<Timecode:00:00:00:10 (10F@25.00)>"
    _(Timecode.new(10, 12).inspect).must_equal "#<Timecode:00:00:00:10 (10F@12.00)>"
  end

  it "properly print itself" do
    _(Timecode.new(5, 25).to_s).must_equal "00:00:00:05"
  end

  it "properly print itself with DF" do
    _(Timecode.new(9662, 29.97, true).to_s).must_equal "00:05:22;12"
    # 9662 frames at 29.97 fps:
    # (9662 / (60 * 29.97)).floor = 5min
    # ((9662 % (60 * 29.97)) / 29.97).floor = 22
    # (9662 % (60 * 29.97)) % 29.97 = 11.6600...
    _(Timecode.new(9662, 29.97, false).to_s).must_equal "00:05:22:11"
  end
end

describe "An existing Timecode compared by adjacency" do
  it "properly detect an adjacent timecode to the left" do
    _(Timecode.new(10)).must_be :adjacent_to?, Timecode.new(9)
    _(Timecode.new(10)).wont_be :adjacent_to?, Timecode.new(8)
  end

  it "properly detect an adjacent DF timecode to the left" do
    _(Timecode.new(1800, 29.97, true)).must_be :adjacent_to?, Timecode.new(1799, 29.97, true)
    _(Timecode.new(1800, 29.97, true)).wont_be :adjacent_to?, Timecode.new(1798, 29.97, true)
  end

  it "properly detect an adjacent timecode to the right" do
    _(Timecode.new(10)).must_be :adjacent_to?, Timecode.new(11)
    _(Timecode.new(10)).wont_be :adjacent_to?, Timecode.new(12)
  end

  it "properly detect an adjacent DF timecode to the right" do
    _(Timecode.new(1799, 29.97, true)).must_be :adjacent_to?, Timecode.new(1800, 29.97, true)
    _(Timecode.new(1799, 29.97, true)).wont_be :adjacent_to?, Timecode.new(1801, 29.97, true)
  end
end

describe "A Timecode on conversion should" do
  it "copy itself with a different framerate" do
    tc = Timecode.new(1800, 25)
    at24 = tc.convert(24)
    _(at24.total).must_equal 1800
    at29 = tc.convert(29.97)
    _(at29.total).must_equal 1800
    # 1800 frames at 29.97 frames per second (no frames dropped) => 1800/29.97 = 60.06sec = 60sec + (1800.0 / 29.97 - 60) * 29.97 frames = 60sec + 1.8 frames
    _(at29.to_s).must_equal "00:01:00:01"
    at29DF = tc.convert(29.97, true)
    _(at29DF.total).must_equal 1800
    _(at29DF.to_s).must_equal "00:01:00;02"

    tc1 = Timecode.new(1800, 23.976, true)
    at29 = tc1.convert(29.97)
    _(at29.total).must_equal 1800
    _(at29.to_s).must_equal "00:01:00;02"
    at29ND = tc1.convert(29.97, false)
    _(at29ND.total).must_equal 1800
    # 1800 frames at 29.97 frames per second (no frames dropped) => 1800/29.97 = 60.06sec = 60sec + (1800.0 / 29.97 - 60) * 29.97 frames = 60sec + 1.8 frames
    _(at29ND.to_s).must_equal "00:01:00:01"
  end
end

describe "An existing Timecode used within ranges should" do
  it "properly provide successive value that is one frame up" do
    _(Timecode.new(10).succ.total).must_equal 11
    _(Timecode.new(22, 45).succ).must_equal Timecode.new(23, 45)
    _(Timecode.new(1799, 29.97, true).succ).must_equal Timecode.new(1800, 29.97, true)
  end

  it "work as a range member" do
    r = Timecode.new(10)...Timecode.new(20)
    _(r.to_a.length).must_equal 10
    _(r.to_a[4]).must_equal Timecode.new(14)
  end

end

describe "A Timecode on calculations should" do

  it "support addition" do
    a, b = Timecode.new(24, 25.000000000000001), Timecode.new(22, 25.000000000000002)
    _((a + b)).must_equal Timecode.new(24 + 22, 25.000000000000001)
  end

  it "should raise on addition if framerates do not match" do
    _(lambda{ Timecode.new(10, 25) + Timecode.new(10, 30) }).must_raise(Timecode::WrongFramerate)
  end

  it "should raise on addition if drop flag mismatches" do
    _(lambda{ Timecode.new(10, 29.97, true) + Timecode.new(10, 29.97) }).must_raise(Timecode::WrongDropFlag)
  end

  it "when added with an integer instead calculate on total" do
    _((Timecode.new(5) + 5)).must_equal(Timecode.new(10))
  end

  it "when adding DF flag is preserved" do
    a, b = Timecode.new(24, 29.97, true), Timecode.new(22, 29.97, true)
    c, d = Timecode.new(24, 29.97), Timecode.new(22, 29.97)
    tcsum = a + b
    _(tcsum).must_equal Timecode.new(24 + 22, 29.97, true)
    _(tcsum.drop?).must_equal true
    _((c + d).drop?).must_equal false
  end

  it "support subtraction" do
    a, b = Timecode.new(10), Timecode.new(4)
    _((a - b)).must_equal Timecode.new(6)
  end

  it "on subtraction of an integer instead calculate on total" do
    _((Timecode.new(15) - 5)).must_equal Timecode.new(10)
  end

  it "raise when subtracting a Timecode with a different framerate" do
    _(lambda { Timecode.new(10, 25) - Timecode.new(10, 30) }).must_raise(Timecode::WrongFramerate)
  end

  it "raise when subtracting a Timecode with a different drop frame flag" do
    _(lambda { Timecode.new(10, 29.97, true) - Timecode.new(10, 29.97) }).must_raise(Timecode::WrongDropFlag)
  end

  it "when subtracting DF flag is preserved" do
    a, b = Timecode.new(24, 29.97, true), Timecode.new(22, 29.97, true)
    c, d = Timecode.new(24, 29.97), Timecode.new(22, 29.97)
    tcsub = a - b
    _(tcsub).must_equal Timecode.new(24 - 22, 29.97, true)
    _(tcsub.drop?).must_equal true
    _((c - d).drop?).must_equal false
  end

  it "support multiplication" do
    _((Timecode.new(10) * 10)).must_equal(Timecode.new(100))
  end

  it "raise when the resultig Timecode is negative" do
    _(lambda { Timecode.new(10) * -200 }).must_raise(Timecode::RangeError)
  end

  it "preserves drop frame flag when multiplying" do
    _((Timecode.new(10, 29.97, true) * 10).drop?).must_equal true
  end

  it "return a Timecode when divided by an Integer" do
    v = Timecode.new(200) / 20
    _(v).must_be_kind_of(Timecode)
    _(v).must_equal Timecode.new(10)
  end

  it "return a number when divided by another Timecode" do
    v = Timecode.new(200) / Timecode.new(20)
    _(v).must_be_kind_of(Numeric)
    _(v).must_equal 10
  end

  it "preserves drop frame flag when dividing" do
    _((Timecode.new(200, 29.97, true) / 20).drop?).must_equal true
  end
end

describe "A Timecode used with fractional number of seconds" do

  it "should properly return fractional seconds" do
    tc = Timecode.new(100 - 1, fps = 25)
    _(tc.frames).must_equal 24

    _(tc.with_frames_as_fraction).must_equal "00:00:03.96"
    _(tc.with_fractional_seconds).must_equal "00:00:03.96"
    _(tc.with_srt_fraction).must_equal "00:00:03,96"
  end

  it "properly translate to frames when instantiated from fractional seconds" do
    fraction = 7.1
    tc = Timecode.from_seconds(fraction, 10)
    _(tc.to_s).must_equal "00:00:07:01"

    fraction = 7.5
    tc = Timecode.from_seconds(fraction, 10)
    _(tc.to_s).must_equal "00:00:07:05"

    fraction = 7.16
    tc = Timecode.from_seconds(fraction, 25)
    _(tc.to_s).must_equal "00:00:07:04"
  end

end

describe "A custom Timecode descendant should" do
  class CustomTC < Timecode; end

  it "properly classify on parse" do
    _(CustomTC.parse("001")).must_be_kind_of CustomTC
  end

  it "properly classify on at" do
    _(CustomTC.at(10,10,10,10)).must_be_kind_of CustomTC
  end

  it "properly  classify on calculations" do
    computed = CustomTC.parse("10h") + Timecode.new(10)
    _(computed).must_be_kind_of CustomTC

    computed = CustomTC.parse("10h") - Timecode.new(10)
    _(computed).must_be_kind_of CustomTC

    computed = CustomTC.parse("10h") * 5
    _(computed).must_be_kind_of CustomTC

    computed = CustomTC.parse("10h") / 5
    _(computed).must_be_kind_of CustomTC
  end

end

describe "Timecode.from_filename_in_sequence should" do
  it "detect the timecode" do
    tc = Timecode.from_filename_in_sequence("foobar.0000012.jpg", fps = 25)
    _(tc).must_equal(Timecode.new(12, 25))
  end
end

describe 'Timecode with hours larger than 99 should' do
  it 'print itself without rollover' do
    tc = Timecode.at(129,34,42,5)
    _(tc.to_s_without_rollover).must_equal '129:34:42:05'
  end

  it 'print itself with rollover when using to_smpte' do
    tc = Timecode.at(129,34,42,5)
    _(tc.to_s).must_equal '29:34:42:05'
  end
end

describe "Timecode.parse should" do

  it "handle complete SMPTE timecode" do
    simple_tc = "00:10:34:10"
    _(Timecode.parse(simple_tc).to_s).must_equal(simple_tc)
  end

  it "handle complete SMPTE timecode with drop frame flag" do
    simple_tc = "00:10:34;10"
    tc = Timecode.parse(simple_tc, 29.97)
    _(tc.to_s).must_equal(simple_tc)
    _(tc.drop?).must_equal true
  end

  it "handle complete SMPTE timecode with plus for 24 frames per second" do
    simple_tc = "00:10:34+10"
    p = Timecode.parse(simple_tc)
    _(p.to_s).must_equal("00:10:34:10")
    _(p.fps).must_equal 24
  end

  it "handle timecode with fractional seconds" do
    tc = Timecode.parse("10:10:10.2", 25)
    _(tc.to_s).must_equal "10:10:10:05"

    tc = Timecode.parse("10:10:10,200", 25)
    _(tc.to_s).must_equal "10:10:10:05"
  end

  it "handle timecode with fractional seconds (euro style, SRT)" do
    tc = Timecode.parse("10:10:10,200", 25)
    _(tc.to_s).must_equal "10:10:10:05"
  end

  it "handle timecode with ticks" do
    tc = Timecode.parse("10:10:10:103", 25)
    _(tc.to_s).must_equal "10:10:10:10"

    tc = Timecode.parse("10:10:10:249", 25)
    _(tc.to_s).must_equal "10:10:10:24"
  end

  it "raise when there are more than 249 ticks" do
    _(lambda { Timecode.parse("10:10:10:250", 25) }).must_raise(Timecode::RangeError)
  end

  it "handle timecode with fractional seconds with spaces at start and end" do
    tc = Timecode.parse(" 00:00:01.040 ")
    _(tc.to_s).must_equal "00:00:01:01"
  end

# I am commenting this one out for now, these were present in some odd subtitle file.
# What we probably need is a way for Timecode to "extract" timecodes from a chunk of text.
# it "handle timecode with fractional seconds with weirdo UTF spaces at start and end" do
#   tc = Timecode.parse("﻿00:00:01.040")
#   tc.to_s.must_equal "00:00:01:01"
# end

  it "parse a row of numbers as parts of a timecode starting from the right" do
    _(Timecode.parse("10")).must_equal Timecode.new(10)
    _(Timecode.parse("210")).must_equal Timecode.new(60)
    _(Timecode.parse("10101010").to_s).must_equal "10:10:10:10"
  end

  it "parse a number with f suffix as frames" do
    _(Timecode.parse("60f")).must_equal Timecode.new(60)
  end

  it "parse a number with s suffix as seconds" do
    _(Timecode.parse("2s", 25)).must_equal Timecode.new(50, 25)
    _(Timecode.parse("2s", 30)).must_equal Timecode.new(60, 30)
  end

  it "parse a number with m suffix as minutes" do
    _(Timecode.parse("3m")).must_equal Timecode.new(25 * 60 * 3)
  end

  it "parse a number with h suffix as hours" do
    _(Timecode.parse("3h")).must_equal Timecode.new(25 * 60 * 60 * 3)
  end

  it "parse different suffixes as a sum of elements" do
    _(Timecode.parse("1h 4f").to_s).must_equal '01:00:00:04'
    _(Timecode.parse("4f 1h").to_s).must_equal '01:00:00:04'
    _(Timecode.parse("29f 1h").to_s).must_equal '01:00:01:04'
    _(Timecode.parse("29f \n\n\n\n\n\    1h").to_s).must_equal '01:00:01:04'
  end

  it "parse a number of digits as timecode" do
    _(Timecode.parse("00000001").to_s).must_equal "00:00:00:01"
    _(Timecode.parse("1").to_s).must_equal "00:00:00:01"
    _(Timecode.parse("10").to_s).must_equal "00:00:00:10"
  end

  it "truncate a large number to the parseable length" do
    _(Timecode.parse("1000000000000000001").to_s).must_equal "10:00:00:00"
  end

  it "left-pad a large number to give proper TC" do
    _(Timecode.parse("123456", 57).to_s).must_equal "00:12:34:56"
  end

  it "parse timecode with fractional second instead of frames" do
    fraction = "00:00:07.1"
    tc = Timecode.parse_with_fractional_seconds(fraction, 10)
    _(tc.to_s).must_equal "00:00:07:01"

    fraction = "00:00:07.5"
    tc = Timecode.parse_with_fractional_seconds(fraction, 10)
    _(tc.to_s).must_equal "00:00:07:05"

    fraction = "00:00:07.08"
    tc = Timecode.parse_with_fractional_seconds(fraction, 12.5)
    _(tc.to_s).must_equal "00:00:07:01"

    fraction = "00:00:07.16"
    tc = Timecode.parse_with_fractional_seconds(fraction, 12.5)
    _(tc.to_s).must_equal "00:00:07:02"
  end

  it "parse timecode with ticks of a second instead of frames" do
    tc_with_ticks = "00:00:07:001"
    tc = Timecode.parse_with_ticks(tc_with_ticks, 10)
    _(tc.to_s).must_equal "00:00:07:00"

    tc_with_ticks = "00:00:07:050"
    tc = Timecode.parse_with_ticks(tc_with_ticks, 10)
    _(tc.to_s).must_equal "00:00:07:02"

    tc_with_ticks = "00:00:07:149"
    tc = Timecode.parse_with_ticks(tc_with_ticks, 12.5)
    _(tc.to_s).must_equal "00:00:07:07"

    tc_with_ticks = "00:00:07:217"
    tc = Timecode.parse_with_ticks(tc_with_ticks, 12.5)
    _(tc.to_s).must_equal "00:00:07:10"
  end

  it "reports DF timecode" do
    df_tc = "00:00:00;01"
    _(Timecode.parse(df_tc, 29.97).drop?).must_equal true
  end

  it "raise on unsupported fraction of seconds" do
    fraction = "00:00:07.149"
    _(lambda { Timecode.parse_with_fractional_seconds(fraction, 12.5, false) }).must_raise Timecode::CannotParse
    tc = Timecode.parse_with_fractional_seconds(fraction, 12.5, true)
    _(tc.to_s).must_equal "00:00:07:01"
  end

  it "raise on unsupported ticks of a second" do
    tc_with_ticks = "00:00:07.050"
    _(lambda { Timecode.parse_with_ticks(tc_with_ticks, 12.5, false) }).must_raise Timecode::CannotParse
    tc = Timecode.parse_with_ticks(tc_with_ticks, 12.5, true)
    _(tc.to_s).must_equal "00:00:07:00"
  end

  it "raise on improper format" do
    _(lambda { Timecode.parse("Meaningless nonsense", 25) }).must_raise Timecode::CannotParse
    _(lambda { Timecode.parse("", 25) }).must_raise Timecode::CannotParse
  end

  it "raise on empty argument" do
    _(lambda { Timecode.parse("   \n\n  ", 25) }).must_raise Timecode::CannotParse
  end

  it "properly handle 09 and 08 as part of complete TC pattern" do
    _(Timecode.parse( "09:08:09:08", 25).total).must_equal 822233
  end

  it "properly handle 10 minute DF timecode" do
    _(Timecode.parse( "00:10:00;00", 29.97).total).must_equal 17982
  end

  it "properly handle non integer fps" do
    _(Timecode.parse( "15:25:13:01", 24000.0/1001.0).total).must_be_within_delta 1330982, 0.02
    _((Timecode.parse( "15:25:13:00", 24000.0/1001.0) + Timecode.at(0, 0, 0, 0.981, 24000.0/1001.0)).total).must_be_within_delta 1330982, 0.0001
    _(Timecode.parse( "15:25:13:01", 30000.0/1001.0).total).must_be_within_delta 1663727, 0.28
    _((Timecode.parse( "15:25:13:00", 30000.0/1001.0) + Timecode.at(0, 0, 0, 0.7263, 30000.0/1001.0)).total).must_be_within_delta 1663727, 0.0001
    _(Timecode.parse( "15:25:13:01", 60000.0/1001.0).total).must_be_within_delta 3327453, 0.55
    _((Timecode.parse( "15:25:13:00", 60000.0/1001.0) + Timecode.at(0, 0, 0, 0.45255, 60000.0/1001.0)).total).must_be_within_delta 3327453, 0.0001

    _(Timecode.parse( "00:25:13:01", 24000.0/1001.0).total).must_be_within_delta 36276, 0.73
    _((Timecode.parse( "00:25:13:00", 24000.0/1001.0) + Timecode.at(0, 0, 0, 0.2757, 24000.0/1001.0)).total).must_be_within_delta 36276, 0.0001
    _(Timecode.parse( "00:25:13:01", 30000.0/1001.0).total).must_be_within_delta 45345, 0.66
    _((Timecode.parse( "00:25:13:00", 30000.0/1001.0) + Timecode.at(0, 0, 0, 0.34466, 30000.0/1001.0)).total).must_be_within_delta 45345, 0.0001
    _(Timecode.parse( "00:25:13:01", 60000.0/1001.0).total).must_be_within_delta 90690, 0.32
    _((Timecode.parse( "00:25:13:00", 60000.0/1001.0) + Timecode.at(0, 0, 0, 0.6893, 60000.0/1001.0)).total).must_be_within_delta 90690, 0.0001

    _(Timecode.parse( "00:00:13:01", 24000.0/1001.0).total).must_be_within_delta 312, 0.69
    _((Timecode.parse( "00:00:13:00", 24000.0/1001.0) + Timecode.at(0, 0, 0, 0.3117, 24000.0/1001.0)).total).must_be_within_delta 312, 0.0001
    _(Timecode.parse( "00:00:13:01", 30000.0/1001.0).total).must_be_within_delta 390, 0.62
    _((Timecode.parse( "00:00:13:00", 30000.0/1001.0) + Timecode.at(0, 0, 0, 0.3896, 30000.0/1001.0)).total).must_be_within_delta 390, 0.0001
    _(Timecode.parse( "00:00:13:01", 60000.0/1001.0).total).must_be_within_delta 780, 0.23
    _((Timecode.parse( "00:00:13:00", 60000.0/1001.0) + Timecode.at(0, 0, 0, 0.7792, 60000.0/1001.0)).total).must_be_within_delta 780, 0.0001
  end
end

describe "Timecode.soft_parse should" do
  it "parse the timecode" do
    _(Timecode.soft_parse('200').to_s).must_equal "00:00:02:00"
  end

  it "not raise on improper format and return zero TC instead" do
    _(lambda do
      tc = Timecode.soft_parse("Meaningless nonsense", 25)
      _(tc).must_equal Timecode.new(0)
    end).must_be_silent
  end
end

describe 'Timecode#to_s' do
  it 'formats 25 and 25 FPS timecodes uniformly' do
    at25 = Timecode.parse("1h", 25)
    at24 = Timecode.parse("1h", 24)
    _(at25.to_s).must_equal "01:00:00:00"
    _(at24.to_s).must_equal "01:00:00:00"
  end
end

describe 'Timecode#inspect' do
  it 'formats 25 and 25 FPS timecodes differently' do
    at25 = Timecode.parse("1h", 25)
    at24 = Timecode.parse("1h", 24)
    _(at25.inspect).must_equal "#<Timecode:01:00:00:00 (90000F@25.00)>"
    _(at24.inspect).must_equal "#<Timecode:01:00:00+00 (86400F@24.00)>"
  end
end

describe "Timecode with unsigned integer conversions should" do

  it "parse from a 4x4bits packed 32bit unsigned int" do
    uint, tc = 87310853, Timecode.at(5,34,42,5)
    _(Timecode.from_uint(uint)).must_equal tc
  end

  it "properly convert itself back to 4x4 bits 32bit unsigned int" do
    uint, tc = 87310853, Timecode.at(5,34,42,5)
    _(tc.to_uint).must_equal uint
  end
end
