import vim, syncrequest, types
class Completion:
    def get_completions(self, column, partialWord):
        parameters = {}
        parameters['column'] = vim.eval(column)
        parameters['wordToComplete'] = vim.eval(partialWord)

        parameters['WantDocumentationForEveryCompletionResult'] = \
            bool(int(vim.eval('g:omnicomplete_fetch_full_documentation')))

        parameters['buffer'] = '\r\n'.join(vim.eval('s:textBuffer')[:])

        response = syncrequest.get_response('/autocomplete', parameters)


        enc = vim.eval('&encoding')
        vim_completions = []
        if response is not None:
            for completion in response:
                complete = {
                    'word': completion['CompletionText'],
                    'menu' : completion['DisplayText'] if completion['DisplayText'] is not None else '',
                    'info': completion['Description'].replace('\r\n', '\n') if completion['Description'] is not None else '',
                    'icase': 1,
                    'dup':1
                }
                vim_completions.append(complete)

        return vim_completions
