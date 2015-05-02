import vim, syncrequest, types
class Completion:
    def get_completions(self, column, partialWord):
        parameters = {}
        parameters['column'] = vim.eval(column)
        parameters['wordToComplete'] = vim.eval(partialWord)

        parameters['WantDocumentationForEveryCompletionResult'] = \
            bool(int(vim.eval('g:omnicomplete_fetch_full_documentation')))

        want_snippet = \
            bool(int(vim.eval('g:omnicomplete_want_snippet')))

        want_method_header = \
            bool(int(vim.eval('g:omnicomplete_want_method_header')))

        want_return_type = \
            bool(int(vim.eval('g:omnicomplete_want_return_type')))

        parameters['WantSnippet'] = want_snippet
        parameters['WantMethodHeader'] = want_method_header
        parameters['WantReturnType'] = want_return_type

        parameters['buffer'] = '\r\n'.join(vim.eval('s:textBuffer')[:])

        response = syncrequest.get_response('/autocomplete', parameters)

        enc = vim.eval('&encoding')
        vim_completions = []
        if response is not None:
            for completion in response:
                complete = {
                    'snip': completion['Snippet'] if completion['Snippet'] is not None else '',
                    'word': completion['MethodHeader'] if completion['MethodHeader'] is not None else completion['CompletionText'],
                    'menu': completion['ReturnType'] if completion['ReturnType'] is not None else completion['DisplayText'],
                    'info': completion['Description'].replace('\r\n', '\n') if completion['Description'] is not None else '',
                    'icase': 1,
                    'dup':1
                }
                vim_completions.append(complete)

        return vim_completions
    def to_dictionary_keyed_by(self, key_by, completions):
        completion_dictionary = {}
        if completions is not None:
            for completion in vim.eval(completions):
                completion_dictionary[completion.get(key_by)] = completion

        return completion_dictionary
