# frozen_string_literal: true

module DeepL
  class DocumentApi
    def initialize(api, options = {})
      @api = api
      @options = options
    end

    ##
    # Uploads the file at the given +input_file_path+ to be translated from +source_lang+ into
    # +target_lang+. The API interface is async, so you need to poll using the returned
    # `DeepL::Resources::DocumentHandle` until the translation is finished, then you can download it
    #
    # @param [String] input_file_path File path to the file to be translated
    # @param [String, nil] source_lang Source language to use for the translation. `nil` will cause
    #                                  automatic source langauge detection to be used. Must be
    #                                  formatted as ISO 639-1, 2-letter language codes.
    # @param [String] target_lang Target language to use for the translation. Must be formatted as
    #                             ISO 639-1, 2-letter language codes, plus a hyphen "-" with the
    #                             variant identifier for languages with variants/dialects/... .
    # @param [String, nil] filename The filename of the file, including its extension. Used to open
    #                               the different kinds of documents (PDFs, etc).
    # @param [Hash] options Additional options for the upload.
    # @return [DeepL::Resources::DocumentHandle] Document handle for the uploaded document.

    def upload(input_file_path, source_lang, target_lang, filename = nil, options = {})
      DeepL::Requests::Document::Upload.new(@api, input_file_path, source_lang, target_lang,
                                            filename, options)
                                       .request
    end

    ##
    # Queries the status of the translation of the document with the given +document_handle+.
    #
    # @param [DeepL::Resources::DocumentHandle] document_handle Handle returned by the `upload`
    # method.
    # @param [Hash] options Additional options for the upload.
    # @return [DeepL::Resources::DocumentTranslationStatus] Status of the document translation.

    def get_status(document_handle, options = {})
      DeepL::Requests::Document::GetStatus.new(@api, document_handle.document_id,
                                               document_handle.document_key, options).request
    end

    ##
    # Downloads the document identified by the +document_handle+ to +output_file+
    #
    # @param [DeepL::Resources::DocumentHandle] document_handle Handle returned by the `upload`
    # method.
    # @param [String] output_file Path to the file to write to. Will be overwritten if the file
    #                             already exists.
    # @return [DeepL::Resources::DocumentTranslationStatus] Status of the document translation.

    def download(document_handle, output_file)
      DeepL::Requests::Document::Download.new(@api, document_handle.document_id,
                                              document_handle.document_key, output_file).request
    end

    ##
    # Translates a document with the DeepL API, `sleep`ing during waiting periods.
    #
    # @raise [DocumentTranslationError] If any error occurs during the process.
    #
    # @param [String] input_file Path to the file to be translated
    # @param [String] output_file Path to the file to write to. Will be overwritten if the file
    #                             already exists.
    # @param [String, nil] source_lang Source language to use for the translation. `nil` will cause
    #                                  automatic source langauge detection to be used. Must be
    #                                  formatted as ISO 639-1, 2-letter language codes.
    # @param [String] target_lang Target language to use for the translation. Must be formatted as
    #                             ISO 639-1, 2-letter language codes, plus a hyphen "-" with the
    #                             variant identifier for languages with variants/dialects/... .
    # @param [String, nil] filename The filename of the file, including its extension. Used to open
    #                               the different kinds of documents (PDFs, etc).
    # @param [Hash] options Additional options for the upload.
    # @return [DeepL::Resources::DocumentTranslationStatus] Status of the document translation.

    def translate_document(input_file, output_file, source_lang, target_lang, filename, # rubocop:disable Metrics/MethodLength
                           options = {})
      raise IOError 'File already exists at output path' if File.exist?(output_file)

      begin
        begin
          handle = upload(input_file, source_lang, target_lang, filename, options)
          translate_document_wait_and_download(handle, output_file)
        rescue StandardError => e
          raise Exceptions::DocumentTranslationError.new(
            "Error occurred during document translation: #{e.message}", handle
          )
        end
      rescue StandardError => e
        FileUtils.rm_f(output_file)
        raise e
      end
    end

    private

    def translate_document_wait_and_download(document_handle, output_file)
      doc_status = document_handle.wait_until_document_translation_finished
      if doc_status.error?
        raise Exceptions::DocumentTranslationError.new(
          "Exception when querying document status #{doc_status.error_message}", document_handle
        )
      else
        download(document_handle, output_file)
      end
    end
  end
end