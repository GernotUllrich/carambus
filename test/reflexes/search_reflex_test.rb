# frozen_string_literal: true

require "test_helper"

# Plan 19-02: SearchReflex loeste params[:controller] per constantize zu einer beliebigen Konstante
# auf. Bei StimulusReflex bestimmt der Client diesen Wert. Jetzt werden nur durchsuchbare Modelle
# (ApplicationRecord-Unterklasse mit search_hash) aufgeloest, alles andere endet ohne Morph.
#
# Muster wie tournament_reflex_test.rb: Reflex per .allocate, Umgebung gestubbt, Aufruf ueber
# `process`, damit die before_reflex-Callbacks mitlaufen.
class SearchReflexTest < ActiveSupport::TestCase
  def reflex_for(controller_name)
    reflex = SearchReflex.allocate
    morphs = []
    session = {}
    params = ActionController::Parameters.new(controller: controller_name, sSearch: "")
    reflex.define_singleton_method(:params) { params }
    reflex.define_singleton_method(:session) { session }
    reflex.define_singleton_method(:request) { OpenStruct.new(base_url: "http://www.example.com") }
    reflex.define_singleton_method(:element) { OpenStruct.new(value: "", dataset: {}) }
    reflex.define_singleton_method(:current_user) { nil }
    reflex.define_singleton_method(:method_name) { "perform" }
    reflex.define_singleton_method(:pagy) { |results| [OpenStruct.new(pages: 1), results.limit(5)] }
    reflex.define_singleton_method(:render) { |*| "<div></div>" }
    reflex.define_singleton_method(:morph) { |selector, *| morphs << selector }
    [reflex, morphs]
  end

  test "Controller-Name ohne Modell loest keine beliebige Konstante auf" do
    reflex, morphs = reflex_for("object_spaces")

    assert_nothing_raised { reflex.process(:perform) }
    assert_empty morphs
    assert_nil reflex.instance_variable_get(:@model), "ObjectSpace darf nicht als Modell aufgeloest werden"
  end

  test "Modell ohne search_hash wird nicht durchsucht" do
    reflex, morphs = reflex_for("users")

    assert_nothing_raised { reflex.process(:perform) }
    assert_empty morphs
  end

  test "durchsuchbares Modell sucht wie bisher" do
    reflex, morphs = reflex_for("players")

    reflex.process(:perform)
    assert_equal ["#table_wrapper"], morphs
    assert_equal Player, reflex.instance_variable_get(:@model)
  end
end
