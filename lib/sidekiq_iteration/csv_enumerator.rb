# frozen_string_literal: true

module SidekiqIteration
  # @private
  # CsvEnumerator makes it possible to write an Iteration job
  # that uses CSV file as a collection to iterate.
  #
  # @example Enumerator to iterate on rows
  #   def build_enumerator(cursor:)
  #     csv = CSV.open('tmp/files', { converters: :integer, headers: true })
  #     csv_enumerator(csv, cursor: cursor)
  #   end
  #
  #   def each_iteration(row)
  #     ...
  #   end
  #
  # @example Enumerator to iterate on batches of rows
  #   def build_enumerator(cursor:)
  #     csv = CSV.open('tmp/files', { converters: :integer, headers: true })
  #     csv_batches_enumerator(csv, cursor: cursor)
  #   end
  #
  #   def each_iteration(row)
  #     ...
  #   end
  #
  class CsvEnumerator
    # Constructs CsvEnumerator instance based on a CSV file.
    #
    # @param [CSV] csv An instance of CSV object
    # @return [SidekiqIteration::CsvEnumerator]
    #
    # @example
    #   csv = CSV.open('tmp/files', { converters: :integer, headers: true })
    #   SidekiqIteration::CsvEnumerator.new(csv).rows(cursor: cursor)
    #
    def initialize(csv)
      unless csv.instance_of?(CSV)
        raise ArgumentError, "CsvEnumerator.new takes CSV object"
      end

      @csv = csv
    end

    # Constructs a enumerator on CSV rows
    # @return [Enumerator] Enumerator instance
    #
    def rows(cursor:)
      @csv.lazy
        .each_with_index
        .drop(count_of_processed_rows(cursor))
        .to_enum { count_of_rows_in_file }
    end

    # Constructs a enumerator on batches of CSV rows
    # @return [Enumerator] Enumerator instance
    #
    def batches(cursor:, batch_size: 100)
      @csv.lazy
        .each_slice(batch_size)
        .with_index
        .drop(count_of_processed_rows(cursor))
        .to_enum { (count_of_rows_in_file.to_f / batch_size).ceil }
    end

    private
      def count_of_rows_in_file
        filepath = @csv.path
        return unless filepath

        count = `wc -l < #{filepath}`.strip.to_i
        count -= 1 if @csv.headers
        count
      end

      def count_of_processed_rows(cursor)
        if cursor
          cursor + 1
        else
          0
        end
      end
  end
end
