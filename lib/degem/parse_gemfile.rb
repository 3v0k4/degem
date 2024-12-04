module Degem
  class ParseGemfile
    def call(gemfile_path)
      dsl = Bundler::Dsl.new
      dsl.eval_gemfile(gemfile_path)
      Gemfile.new(dsl)
    end

    private

    def definition(gemfile_path)
      Bundler::Dsl.evaluate(gemfile_path, nil, {})
    end
  end
end
