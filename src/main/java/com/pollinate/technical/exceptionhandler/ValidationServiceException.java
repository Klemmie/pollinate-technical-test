package com.pollinate.technical.exceptionhandler;

public class ValidationServiceException extends RuntimeException{
    public ValidationServiceException(String message){
        super(message);
    }

    public ValidationServiceException(String message, Throwable cause){
        super(message, cause);
    }
}
