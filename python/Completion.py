import vim, syncrequest, types
class Completion:
    def get_completions(self, column, partialWord):
        parameters = {}
        parameters['column'] = vim.eval(column)
        parameters['wordToComplete'] = vim.eval(partialWord)

        parameters['WantDocumentationForEveryCompletionResult'] = \
            bool(int(vim.eval('g:omnicomplete_fetch_full_documentation')))

        want_snippet = \
            bool(int(vim.eval('g:OmniSharp_want_snippet')))

        parameters['WantSnippet'] = want_snippet
        parameters['WantMethodHeader'] = want_snippet
        parameters['WantReturnType'] = want_snippet

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
