""" Exceptions thrown by the omnisharp-vim plugin """


class ServerConnectionError(Exception):
    """ There was an error when trying to communicate to the server """
    code = "CONNECTION"


class BadResponseError(Exception):
    """ Received a malformed response from the server """
    code = "BAD_RESPONSE"
