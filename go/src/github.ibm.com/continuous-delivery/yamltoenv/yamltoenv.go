package main

import (
        "encoding/json"
        "fmt"
        "io/ioutil"
        "os"
        "path/filepath"
        "text/tabwriter"
	"bufio"
	"strings"
        "github.com/sirupsen/logrus"
        "github.com/hashicorp/go-cleanhttp"
        "github.com/hashicorp/vault/api"
//        "os/signal"
//        "syscall"
)

const (
        credentialsPath = "/var/run/secrets/boostport.com"
)

type authToken struct {
        ClientToken   string `json:"clientToken"`
        Accessor      string `json:"accessor"`
        LeaseDuration int    `json:"leaseDuration"`
        Renewable     bool   `json:"renewable"`
        VaultAddr     string `json:"vaultAddr"`
}

type secretID struct {
        RoleID    string `json:"roleId"`
        SecretID  string `json:"secretId"`
        Accessor  string `json:"accessor"`
        VaultAddr string `json:"vaultAddr"`
}


func main() {

        logger := logrus.New()
        logger.Level = logrus.DebugLevel

        tokenPath := filepath.Join(credentialsPath, "vault-token")
        secretIDPath := filepath.Join(credentialsPath, "vault-secret-id")

	secretPath := os.Getenv("SECRET_PATHS");
	if len(secretPath) <= 0 {
           logger.Fatal("SECRET_PATHS environmental variable must be defined")
	}
        w := tabwriter.NewWriter(os.Stdout, 0, 0, 2, ' ', 0)

	var c *api.Logical

	httpClient := cleanhttp.DefaultPooledClient()

        if _, err := os.Stat(tokenPath); err == nil {
                content, err := ioutil.ReadFile(tokenPath)

                if err != nil {
                        logger.Fatalf("Error opening token file (%s): %s", tokenPath, err)
                }

                var token authToken

                err = json.Unmarshal(content, &token)

                if err != nil {
                        logger.Fatalf("Error unmarhsaling JSON: %s", err)
                }

                fmt.Fprint(w, "Found Vault token...\n")
//                fmt.Fprintf(w, "Token:\t%s\n", token.ClientToken)
//                fmt.Fprintf(w, "Accessor:\t%s\n", token.Accessor)
//                fmt.Fprintf(w, "Lease Duration:\t%d\n", token.LeaseDuration)
//                fmt.Fprintf(w, "Renewable:\t%t\n", token.Renewable)
//                fmt.Fprintf(w, "Vault Address:\t%s\n", token.VaultAddr)

		client, err := api.NewClient(&api.Config{Address: token.VaultAddr, HttpClient: httpClient})
		if err != nil {
			logger.Fatal(err)
		}

		client.SetToken(token.ClientToken)
		c = client.Logical()

        } else if _, err := os.Stat(secretIDPath); err == nil {

                content, err := ioutil.ReadFile(secretIDPath)

                if err != nil {
                        logger.Fatalf("Error opening secret_id file (%s): %s", secretIDPath, err)
                }

                var secret secretID

                err = json.Unmarshal(content, &secret)

                if err != nil {
                        logger.Fatalf("Error unmarhsaling JSON: %s", err)
                }

                fmt.Fprint(w, "Found Vault secret_id...\n")
//                fmt.Fprintf(w, "RoleID:\t%s\n", secret.RoleID)
//                fmt.Fprintf(w, "SecretID:\t%s\n", secret.SecretID)
//                fmt.Fprintf(w, "Accessor:\t%s\n", secret.Accessor)
//                fmt.Fprintf(w, "Vault Address:\t%s\n", secret.VaultAddr)

		client, err := api.NewClient(&api.Config{Address: secret.VaultAddr, HttpClient: httpClient})
		token, err := client.Logical().Write("auth/approle/login", map[string]interface{}{
			"role_id":   secret.RoleID,
			"secret_id": secret.SecretID,
		})

		if err != nil {
			logger.Fatalf("could not log in using secret_id (%s): %s", err)
		}

		client.SetToken(token.Auth.ClientToken)
		c = client.Logical()

        } else {
                logger.Fatal("Could not find a vault-token or vault-secret-id.")
        }

	f, err := os.Create(filepath.Join(credentialsPath, "secrets.sh"))
	if err != nil {
		logger.Fatal(err)
	}
	defer f.Close()
	w2 := bufio.NewWriter(f)

	result := strings.Split(secretPath, ",")
	for i := range result {
		s, err := c.Read(strings.TrimSpace(result[i]))
		if err != nil {
			logger.Fatal(err)
		}
		if s == nil {
			logger.Fatal("secret was nil")
		}
		for k, v := range s.Data {
			_, err := w2.WriteString(fmt.Sprintf("export %s=%q\n", k, v))
			if err != nil {
				logger.Fatal(err)
			}
		}
	}
	w2.Flush()
        w.Flush()

//        sigs := make(chan os.Signal, 1)
//       signal.Notify(sigs, syscall.SIGINT, syscall.SIGTERM)
//      <-sigs
}
