package main

import (
	"fmt"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

func main() {
	// JWT secret from .env
	secret := []byte("iHV8n9mDsI73WO3dre3Es5KpsGZC/tIua1EH7ZPnTDVOeMswL4pRXjO3xvjmOCuLhMEgY0pYBUiaRoMiD+o2HA==")
	
	// Create claims
	claims := jwt.MapClaims{
		"sub":   "a56abd28-a46e-4e61-8dd2-82ba6799b1f2",
		"email": "testuser@apexrun.app",
		"role":  "authenticated",
		"aud":   "authenticated",
		"iat":   time.Now().Unix(),
		"exp":   time.Now().Add(time.Hour).Unix(),
	}

	// Create token
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	
	// Sign and get the complete encoded token as a string
	tokenString, err := token.SignedString(secret)
	if err != nil {
		panic(err)
	}

	fmt.Println("JWT Token:")
	fmt.Println(tokenString)
}
