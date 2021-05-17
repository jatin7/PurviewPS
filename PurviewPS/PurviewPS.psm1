#region PurviewPSClasses

Class Token
{
    
        [String]$tokenType
        [String]$expiresIn
        [String]$extExpiresIn
        [String]$expiresOn
        [String]$notBefore
        [String]$resource
        [String]$accessToken
    


    Token($json){
        
        $this.tokenType = $json.token_type
        $this.expiresIn = $json.expires_in
        $this.expiresOn = $json.expires_on
        $this.extExpiresIn = $json.ext_expires_in
        $this.notBefore = $json.not_before
        $this.resource = $json.resource
        $this.accessToken = $json.access_token
    }


}

Class Client

{
    [String]$clientID
    [String]$clientSecret
    [String]$applicationID  #known as resource in 
    [String]$purviewName
    [String]$tenantID
    [Token]$token
    [int]$Delete = 5
    [int]$Get = 1
    [int]$Post = 3
    [int]$Put = 4



    Client($ClientID, $ClientSecret, $ApplicationID, $PurviewName, $TenantID){

        $this.clientID = $ClientID
        $this.clientSecret = $ClientSecret
        $this.applicationID =$ApplicationID
        $this.purviewName = $PurviewName
        $this.tenantID =  $TenantID
    
    }

    FetchToken(){

        $tokenURL = "https://login.microsoftonline.com/$($this.tenantID)/oauth2/token"
        $headers = $this.CreateTokenHeaders()
        $body =$this.CreateTokenBody()

        $response = Invoke-RestMethod -Uri $tokenURL -Headers $headers -Body $body -Method Post 

        $this.token = [Token]::new($response)

    }

    [System.Collections.Generic.Dictionary[[String],[String]]] CreateTokenHeaders(){

        $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $headers.Add('Accept','*/*')
        $headers.Add('Content-Type','application/x-www-form-urlencoded')

        return $headers

    }

    [System.Collections.Hashtable] CreateTokenBody(){
    
    $body = @{grant_type='client_credentials'
      client_id="$($this.clientID)"
      client_secret="$($this.clientSecret)"
      resource="$($this.applicationID)"
      }

    return $body

    }

    [System.Collections.Generic.Dictionary[[String],[String]]] CreateRequestHeaders(){

        $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $headers.Add('Authorization', "Bearer $($this.token.accessToken)")
        $headers.Add('Content-Type','application/json')

        return $headers

    }

    [Object] MakeRequest([String]$Resource, [object]$Payload, $Method, [String]$Version){

        $URL = "https://$($this.PurviewName).catalog.purview.azure.com/api/atlas/$($Version)/$($Resource)"
        $headers = $this.CreateRequestHeaders()
        $RestError = $false

        
        #First attemp at web request
        if($Payload ){
            $response = Invoke-RestMethod -URI $URL -Method $Method -Headers $headers -ErrorVariable RestError -ErrorAction SilentlyContinue -Body ConvertTo-Json($Payload)
        }else{
            $response = Invoke-RestMethod -URI $URL -Method $Method -Headers $headers -ErrorVariable RestError -ErrorAction SilentlyContinue
        }

        

        if ($RestError)
        {
            $HttpStatusCode = $RestError.ErrorRecord.Exception.Response.StatusCode.value__
            $HttpStatusDescription = $RestError.ErrorRecord.Exception.Response.StatusDescription
            
            #if response is unauthorized
            if($HttpStatusCode == 401){
                $errorObject = ConvertFrom-Json($HttpStatusDescription)

                #and the message in the response is 'invalid token' then refresh the token and resend
                if($errorObject.error.message == "Token expired"){
                    $this.FetchToken()
                    $RestErrorRetry = $false
                    if($Payload ){
                        $response = Invoke-RestMethod -URI $URL -Method $Method -Headers $headers -ErrorVariable RestErrorRetry -ErrorAction SilentlyContinue -Body ConvertTo-Json($Payload)
                    }else{
                        $response = Invoke-RestMethod -URI $URL -Method $Method -Headers $headers -ErrorVariable RestErrorRetry -ErrorAction SilentlyContinue
                    }

                    if($RestErrorRetry){

                        $HttpStatusCode = $RestErrorRetry.ErrorRecord.Exception.Response.StatusCode.value__
                        $HttpStatusDescription = $RestErrorRetry.ErrorRecord.Exception.Response.StatusDescription

                        Throw "Http Status Code: $($HttpStatusCode) `nHttp Status Description: $($HttpStatusDescription)"
                    }

                }else{
                    Throw "Http Status Code: $($HttpStatusCode) `nHttp Status Description: $($HttpStatusDescription)"
                }
            }

            
        }

        return $response

    }

}

#endregion

#region AtlasClasses

class AttributeSearchResult{
    #Todo: Implement
}

class AttributeEntityHeader{
    #Todo: Implement

    AttributeEntityHeader(){}
}

class AtlasFullTextResult{
    #Todo: Implement
}

class AtlasQueryType{
    #Todo: Implement
}


class AtlasSearchResult {

    [Int]$approximateCount
    
    [AttributeSearchResult]$attributes
  
    [String]$classification

    [AttributeEntityHeader[]]$entities

    [AtlasFullTextResult[]]$fullTextResult

    [String]$queryText

    [AtlasQueryType]$queryType

    [System.Collections.Generic.Dictionary[[String],[AttributeEntityHeader]]]$referredEntities

    

}



#endregion

function New-PurviewClient {

    param(
    
        [Parameter(
            Mandatory=$true
            , HelpMessage="The Client ID of the authenticating SPN for purview"
        )]
        [ValidatePattern('(\{|\()?[A-Za-z0-9]{4}([A-Za-z0-9]{4}\-?){4}[A-Za-z0-9]{12}(\}|\()?')]
        [String]$ClientID,

        [Parameter(
            Mandatory=$true
            , HelpMessage="The Client secret of the authenticating SPN for purview"
        )]
        [String]$ClientSecret,

        [Parameter(
            Mandatory=$true
            , HelpMessage="The Application ID of the app registration for purview"
        )]
        [ValidatePattern('(\{|\()?[A-Za-z0-9]{4}([A-Za-z0-9]{4}\-?){4}[A-Za-z0-9]{12}(\}|\()?')]
        [String]$ApplicationID,

        [Parameter(
            Mandatory=$true
            , HelpMessage="The name of the purview instance, used in generation of atlas URL"
        )]
        [String]$PurviewName,

        [Parameter(
            Mandatory=$true
            , HelpMessage="The TenantID containg the purview Instance"
        )]
        [ValidatePattern('(\{|\()?[A-Za-z0-9]{4}([A-Za-z0-9]{4}\-?){4}[A-Za-z0-9]{12}(\}|\()?')]
        [String]$TenantID
    
    )


   $newClient = [Client]::new($ClientID, $ClientSecret, $ApplicationID, $PurviewName, $TenantID)
   $newClient.FetchToken()

   return $newClient

}

#region Entity API

function Get-Entity{

    Param(

        [Parameter(
            Mandatory=$true
            , HelpMessage="The client to perform the request"
        )]
        [parameter(ParameterSetName = "All")]
        [parameter(ParameterSetName = "GUID")]
        [parameter(ParameterSetName = "Audit")]
        [parameter(ParameterSetName = "GuidHeaders")]
        [parameter(ParameterSetName = "BulkHeaders")]
        [parameter(ParameterSetName = "TypeHeaders")]
        [parameter(ParameterSetName = "ImportTemplate")]
        [parameter(ParameterSetName = "BulkClassifications")]
        [parameter(ParameterSetName = "GuidClassifications")]
        [parameter(ParameterSetName = "GuidClassificationsName")]
        [parameter(ParameterSetName = "UniqueAttribute")]
        [Client]$Client,

        [Parameter(ParameterSetName="All")]
        [parameter(ParameterSetName = "BulkHeaders")]
        [Switch]$All,

        [ValidatePattern('(\{|\()?[A-Za-z0-9]{4}([A-Za-z0-9]{4}\-?){4}[A-Za-z0-9]{12}(\}|\()?')]
        [Parameter(ParameterSetName="GUID")]
        [parameter(ParameterSetName = "Classifications")]
        [parameter(ParameterSetName = "Audit")]
        [parameter(ParameterSetName = "GuidHeaders")]
        [parameter(ParameterSetName = "GuidClassificationsName")]
        [String]$Guid,

        [parameter(ParameterSetName = "BulkHeaders")]
        [parameter(ParameterSetName = "GuidHeaders")]
        [parameter(ParameterSetName = "TypeHeaders")]
        [Switch]$Headers,

        [parameter(ParameterSetName = "Audit")]
        [Switch]$Audit,

        [parameter(ParameterSetName = "ImportTemplate")]
        [Switch]$ImportTemplate,

        
        [parameter(ParameterSetName = "GuidClassifications")]
        [parameter(ParameterSetName = "GuidClassificationsName")]
        [Switch]$Classifications,

        [parameter(ParameterSetName = "UniqueAttribute")]
        [Switch]$uniqueAttribute,

        [parameter(ParameterSetName = "UniqueAttribute")]
        [parameter(ParameterSetName = "TypeHeaders")]
        [String]$TypeName,

        [parameter(ParameterSetName = "GuidClassificationsName")]
        [String]$ClassificationName

    )


     $FunctionType = $PSCmdlet.ParameterSetName

     Switch ($FunctionType)
        {
            "All" {
            
                return $Client.MakeRequest("entity/bulk", $false, $client.Get , "v2")

            }
            "GUID" {
            
                return $Client.MakeRequest("entity/guid/$($Guid)", $false, $client.Get , "v2")

            }
         "Audit"{
            
                return $Client.MakeRequest("entity/guid/$($Guid)/audit", $false, $client.Get , "v2")

            }
         "GuidHeaders"{
            
                return $Client.MakeRequest("entity/guid/$($Guid)/header", $false, $client.Get , "v2")

            }
         "BulkHeaders"{
            
                return $Client.MakeRequest("entity/bulk/headers", $false, $client.Get , "v2")

            }
         "TypeHeaders"{
            
                return $Client.MakeRequest("entity/guid/$($TypeName)/Headers", $false, $client.Get , "v2")

            }
         "ImportTemplate"{
            
                return $Client.MakeRequest("entity/businessmetadata/import/template", $false, $client.Get , "v2")

            }
         "GuidClassifications"{
            
                return $Client.MakeRequest("entity/guid/$($Guid)/classifications", $false, $client.Get , "v2")

            }
         "GuidClassificationsName"{
            
                return $Client.MakeRequest("entity/guid/$($Guid)/classification/$($ClassificationName)", $false, $client.Get , "v2")

            }
         "UniqueAttribute"{
            
                return $Client.MakeRequest("entity/uniqueAttribute/type/$($TypeName)", $false, $client.Get , "v2")

            }

        }

}
function Add-Entity{
    Param(
        [Parameter(
            Mandatory=$true
            , HelpMessage="The client to perform the request"
        )]
        [parameter(ParameterSetName = "entity")]
        [parameter(ParameterSetName = "entityBulk")]
        [parameter(ParameterSetName = "classifications")]
        [parameter(ParameterSetName = "classificationsBulk")]
        [parameter(ParameterSetName = "classificationDefTypeName")]
        [parameter(ParameterSetName = "BusinessMetaDataBulk")]
        [parameter(ParameterSetName = "GUIDBusinessMetaData")]
        [parameter(ParameterSetName = "NameBusinessMetaData")]
        [parameter(ParameterSetName = "LabelsDef")]
        [parameter(ParameterSetName = "GuidLabels")]
        [Client]$Client,

        [parameter(ParameterSetName = "entity")]
        [parameter(ParameterSetName = "entityBulk")]
        [Object]$EntityDef,

        [parameter(ParameterSetName = "classifications")]
        [parameter(ParameterSetName = "classificationsBulk")]
        [parameter(ParameterSetName = "classificationDefTypeName")]
        [parameter(ParameterSetName = "GuidClassifications")]
        [Object]$ClassificationDef,

        [parameter(ParameterSetName = "entityBulk")]
        [parameter(ParameterSetName = "classificationsBulk")]
        [parameter(ParameterSetName = "NameBusinessMetaData")]
        [Switch]$Bulk,

        [parameter(ParameterSetName = "BusinessMetaDataBulk")]
        [parameter(ParameterSetName = "GUIDBusinessMetaData")]
        [parameter(ParameterSetName = "NameBusinessMetaData")]
        [Object]$BusinessMetaDataDef,

        [parameter(ParameterSetName = "NameBusinessMetaData")]
        [String]$BusinessMetaDataName,

        [parameter(ParameterSetName = "LabelsTypeName")]
        [parameter(ParameterSetName = "classificationDefTypeName")]
        [String]$TypeName,

        [parameter(ParameterSetName = "LabelsTypeName")]
        [parameter(ParameterSetName = "GuidLabels")]
        [Object]$LabelsDef,

        [Parameter(
             HelpMessage="The quilivant of GET /v2/entity/guid{guid}"
            , ParameterSetName="GUID"
            )]
        [ValidatePattern('(\{|\()?[A-Za-z0-9]{4}([A-Za-z0-9]{4}\-?){4}[A-Za-z0-9]{12}(\}|\()?')]
        [parameter(ParameterSetName = "GUIDBusinessMetaData")]
        [parameter(ParameterSetName = "GuidLabels")]
        [parameter(ParameterSetName = "NameBusinessMetaData")]
        [parameter(ParameterSetName = "GuidClassifications")]
        [String]$Guid
        )
        
     $FunctionType = $PSCmdlet.ParameterSetName

     Switch ($FunctionType) {

        "entity" {  
            return $Client.MakeRequest("entity", $EntityDef, $client.Post , "v2") 
        }
        "entityBulk" {
            return $Client.MakeRequest("entity/bulk", $EntityDef, $client.Post , "v2") 
         }
        "classificationsBulk" {  
            return $Client.MakeRequest("entity/bulk/classification", $ClassificationDef, $client.Post , "v2") 
         }
        "BusinessMetaDataBulk" {  
            return $Client.MakeRequest("entity/businessmetadata/import", $BusinessMetaDataDef, $client.Post , "v2") 
         }
        "GUIDBusinessMetaData" {  
            return $Client.MakeRequest("entity/guid/$($guid)/businessmetadata", $BusinessMetaDataDef, $client.Post , "v2") 
         }
        "GuidClassifications" {  
            return $Client.MakeRequest("entity/guid/$($guid)/classifications", $ClassificationDef, $client.Post , "v2") 
         }
        "GuidLabels" {  
            return $Client.MakeRequest("entity/guid/$($guid)/labels", $LabelsDef, $client.Post , "v2") 
         }
        "NameBusinessMetaData" {  
            return $Client.MakeRequest("entity/guid/$($guid)/businessmetadata/$($BusinessMetaDataName)", $BusinessMetaDataDef, $client.Post , "v2") 
         }
        "classificationDefTypeName" {  
            return $Client.MakeRequest("entity/uniqueAttribute/type/$($TypeName)/classifications", $ClassificationDef, $client.Post , "v2") 
         }
        "LabelsTypeName" {  
            return $Client.MakeRequest("entity/uniqueAttribute/type/$($TypeName)/labels", $LabelsDef, $client.Post , "v2") 
         }

     }

}
function Set-Entity{

    Param(
    
    [Parameter(
            Mandatory=$true
            , HelpMessage="The client to perform the request"
        )]
        [parameter(ParameterSetName = "guidEntity")]
        [parameter(ParameterSetName = "guidClassifications")]
        [parameter(ParameterSetName = "guidLabels")]
        [parameter(ParameterSetName = "uniqueAttribute")]
        [parameter(ParameterSetName = "typeNameClassifications")]
        [parameter(ParameterSetName = "typeNameLabels")]
        [Client]$Client,

        [parameter(ParameterSetName = "uniqueAttribute")]
        [parameter(ParameterSetName = "typeNameClassifications")]
        [parameter(ParameterSetName = "typeNameLabels")]
        [String]$TypeName,

        [parameter(ParameterSetName = "guidEntity")]
        [Object]$EntityDef,
        
        [parameter(ParameterSetName = "guidClassifications")]
        [parameter(ParameterSetName = "typeNameClassifications")]
        [Object]$ClassificationDef,
        
        [parameter(ParameterSetName = "guidLabels")]
        [parameter(ParameterSetName = "typeNameLabels")]
        [Object]$LabelDef,

        [parameter(ParameterSetName = "uniqueAttribute")]
        [Object]$TypeDef,
         
        [Parameter(
             HelpMessage="The quilivant of GET /v2/entity/guid{guid}"
            , ParameterSetName="GUID"
            )]
        [ValidatePattern('(\{|\()?[A-Za-z0-9]{4}([A-Za-z0-9]{4}\-?){4}[A-Za-z0-9]{12}(\}|\()?')]
        [parameter(ParameterSetName = "guidEntity")]
        [parameter(ParameterSetName = "guidClassifications")]
        [parameter(ParameterSetName = "guidLabels")]
        [String]$Guid
        

    )

    $FunctionType = $PSCmdlet.ParameterSetName

    Switch ($FunctionType) {

        "guidEntity" {  
            return $Client.MakeRequest("entity/guid/$($guid)", $EntityDef, $client.Post , "v2") 
        }

        "guidClassifications" {  
            return $Client.MakeRequest("entity/guid/$($guid)/classifications", $ClassificationDef, $client.Post , "v2") 
        }

        "guidLabels" {  
            return $Client.MakeRequest("entity/guid/$($guid)/labels", $LabelDef, $client.Post , "v2") 
        }

        "uniqueAttribute" {  
            return $Client.MakeRequest("entity/uniqueAttribute/type/$($TypeName)", $TypeDef, $client.Post , "v2") 
        }

        "typeNameClassifications" {  
            return $Client.MakeRequest("entity/uniqueAttribute/type/$($TypeName)/classifications", $ClassificationDef, $client.Post , "v2") 
        }

        "typeNameLabels" {  
            return $Client.MakeRequest("entity/uniqueAttribute/type/$($TypeName)/labels", $LabelDef, $client.Post , "v2") 
        }
    }


}
function Remove-Entity {

    Param(

        [Parameter(
            Mandatory=$true
            , HelpMessage="The client to perform the request"
        )]
        [parameter(ParameterSetName = "guidEntity")]
        [parameter(ParameterSetName = "bulkEntity")]
        [parameter(ParameterSetName = "guidBusinessMetaData")]
        [parameter(ParameterSetName = "guidLabels")]
        [parameter(ParameterSetName = "BusinessMetadataName")]
        [parameter(ParameterSetName = "ClassificationsName")]
        [parameter(ParameterSetName = "typeNameLabels")]
        [parameter(ParameterSetName = "uniqueAttribute")]
        [parameter(ParameterSetName = "typeNameClassification")]
        [Client]$Client,

        [parameter(ParameterSetName = "bulkEntity")]
        [Switch]$Bulk,


        [Parameter(
             HelpMessage="The quilivant of GET /v2/entity/guid{guid}"
            , ParameterSetName="GUID"
            )]
        [ValidatePattern('(\{|\()?[A-Za-z0-9]{4}([A-Za-z0-9]{4}\-?){4}[A-Za-z0-9]{12}(\}|\()?')]
        [parameter(ParameterSetName = "guidEntity")]
        [parameter(ParameterSetName = "guidBusinessMetaData")]
        [parameter(ParameterSetName = "guidLabels")]
        [parameter(ParameterSetName = "BusinessMetadataName")]
        [parameter(ParameterSetName = "ClassificationsName")]
        [String]$Guid,

        [parameter(ParameterSetName = "bulkEntity")]
        [Object]$EntityDef,

        [parameter(ParameterSetName = "guidBusinessMetaData")]
        [Switch]$BusinessMetadata,

        [parameter(ParameterSetName = "guidLabels")]
        [parameter(ParameterSetName = "typeNameLabels")]
        [Switch]$Labels,

        [parameter(ParameterSetName = "uniqueAttribute")]
        [parameter(ParameterSetName = "typeNameLabels")]
        [parameter(ParameterSetName = "typeNameClassification")]
        [String]$TypeName,

        [parameter(ParameterSetName = "BusinessMetadataName")]
        [String]$BusinessMetadataName,

        [parameter(ParameterSetName = "ClassificationsName")]
        [parameter(ParameterSetName = "typeNameClassification")]
        [String]$ClassificationsName


        )

        $FunctionType = $PSCmdlet.ParameterSetName

        Switch ($FunctionType) {

        "guidEntity"{  
            return $Client.MakeRequest("entity/guid/$($guid)", $false, $client.Delete , "v2") 
        }
        "bulkEntity"{  
                return $Client.MakeRequest("entity/bulk/$($guid)", $EntityDef, $client.Delete , "v2") 
        }
         "guidBusinessMetaData"{  
                return $Client.MakeRequest("entity/guid/$($guid)/businessmetadata", $false, $client.Delete , "v2") 
        }
        "guidLabels"{  
                return $Client.MakeRequest("entity/guid/$($guid)/labels", $false, $client.Delete , "v2") 
        }
        "BusinessMetadataName"{  
                return $Client.MakeRequest("entity/guid/$($guid)/businessmetadata/$($BusinessMetadataName)", $false, $client.Delete , "v2") 
        }
         "ClassificationsName"{  
                return $Client.MakeRequest("entity/guid/$($guid)/classification/$($ClassificationsName)", $false, $client.Delete , "v2") 
        }
         "typeNameLabels"{  
                return $Client.MakeRequest("entity/guid/$($guid)", $false, $client.Delete , "v2") 
        }
         "uniqueAttribute"{  
                return $Client.MakeRequest("entity/uniqueAttribute/type/$($TypeName)", $false, $client.Delete , "v2") 
        }
         "typeNameClassification"{  
                return $Client.MakeRequest("entity/uniqueAttribute/type/$($TypeName)/classification/$($ClassificationsName)", $false, $client.Delete , "v2") 
        }

            
            





  }

}

#endregion

#region TypeDefs API

function Get-TypeDefs{

    Param(

        [Parameter(
            Mandatory=$true
            , HelpMessage="The client to perform the request"
        )]
        [parameter(ParameterSetName = "All")]
        [parameter(ParameterSetName = "Headers")]
        [parameter(ParameterSetName = "businessmetadatadefname")]
        [parameter(ParameterSetName = "classificationdefname")]
        [parameter(ParameterSetName = "entitydefname")]
        [parameter(ParameterSetName = "enumdefname")]
        [parameter(ParameterSetName = "relationshipdefname")]
        [parameter(ParameterSetName = "structdefname")]
        [parameter(ParameterSetName = "typedefname")]
        [parameter(ParameterSetName = "businessmetadatadefguid")]
        [parameter(ParameterSetName = "classificationdefguid")]
        [parameter(ParameterSetName = "entitydefguid")]
        [parameter(ParameterSetName = "enumdefguid")]
        [parameter(ParameterSetName = "relationshipdefguid")]
        [parameter(ParameterSetName = "structdefguid")]
        [parameter(ParameterSetName = "typedefguid")]
        [Client]$Client,

        [Parameter(
             HelpMessage="The quilivant of GET /v2/types/typedefs"
            , ParameterSetName="All"
        )]
        [Switch]$All,

        [Parameter(
             HelpMessage="The quilivant of GET /v2/types/typedefs/headers"
            , ParameterSetName="Headers"
            )]
        [Switch]$Headers,

        [Parameter(
             HelpMessage="The TypeDef GUID"
            )]
        [ValidatePattern('(\{|\()?[A-Za-z0-9]{4}([A-Za-z0-9]{4}\-?){4}[A-Za-z0-9]{12}(\}|\()?')]
        [parameter(ParameterSetName = "businessmetadatadefguid")]
        [parameter(ParameterSetName = "classificationdefguid")]
        [parameter(ParameterSetName = "entitydefguid")]
        [parameter(ParameterSetName = "enumdefguid")]
        [parameter(ParameterSetName = "relationshipdefguid")]
        [parameter(ParameterSetName = "structdefguid")]
        [parameter(ParameterSetName = "typedefguid")]
        [String]$Guid,

        [Parameter(
             HelpMessage="The TypeDef Name"
            )]
        [parameter(ParameterSetName = "businessmetadatadefname")]
        [parameter(ParameterSetName = "classificationdefname")]
        [parameter(ParameterSetName = "entitydefname")]
        [parameter(ParameterSetName = "enumdefname")]
        [parameter(ParameterSetName = "relationshipdefname")]
        [parameter(ParameterSetName = "structdefname")]
        [parameter(ParameterSetName = "typedefname")]
        [String]$Name,

        [Parameter(
             HelpMessage="The TypeDef TypeName"
            )]
        [String]$TypeName,



        [Parameter(
             HelpMessage="The quilivant of GET types/businessmetadatadef/*/*}"
            )]
        [parameter(ParameterSetName = "businessmetadatadefguid")]
        [parameter(ParameterSetName = "businessmetadatadefname")]
        [Switch]$Businessmetadatadef,

        [Parameter(
             HelpMessage="The quilivant of GET types/classificationdef/*/*"
            )]
        [parameter(ParameterSetName = "classificationdefname")]
        [parameter(ParameterSetName = "classificationdefguid")]
        [Switch]$Classificationdef,

        [Parameter(
             HelpMessage="The quilivant of GET types/classificationdef/*/*"
            )]
        [parameter(ParameterSetName = "entitydefguid")]
        [parameter(ParameterSetName = "entitydefname")]
        [Switch]$Entitydef,

        [Parameter(
             HelpMessage="The quilivant of GET types/enumdef/*/*"
            )]
        [parameter(ParameterSetName = "enumdefguid")]
        [parameter(ParameterSetName = "enumdefname")]
        [Switch]$Enumdef,

        [Parameter(
             HelpMessage="The quilivant of GET types/relationshipdef/*/*"
            )]
        [parameter(ParameterSetName = "relationshipdefguid")]
        [parameter(ParameterSetName = "relationshipdefname")]
        [Switch]$Relationshipdef,

        [Parameter(
             HelpMessage="The quilivant of GET types/structdef/*/*"
            )]
        [parameter(ParameterSetName = "structdefguid")]
        [parameter(ParameterSetName = "structdefname")]
        [Switch]$Structdef,

        [Parameter(
             HelpMessage="The quilivant of GET types/entitydef/*/*"
            )]
        [parameter(ParameterSetName = "typedefguid")]
        [parameter(ParameterSetName = "typedefname")]
        [Switch]$Typedef

    )

     $FunctionType = $PSCmdlet.ParameterSetName
     

     Switch ($FunctionType)
        {
            "All" {
            
                return $Client.MakeRequest("types/typedefs", $false, $client.Get , "v2")

            }
            "Headers" {
            
                return $Client.MakeRequest("types/typedefs/headers", $false, $client.Get , "v2")

            }
            
           "businessmetadatadefname" {
           
                return $Client.MakeRequest("types/businessmetadatadef/name/$($guid)", $false, $client.Get , "v2")

           }
           "classificationdefname"{
           
                return $Client.MakeRequest("types/classificationdef/name/$($guid)", $false, $client.Get , "v2")

           }
           "entitydefname" {
           
                return $Client.MakeRequest("types/entitydef/name/$($guid)", $false, $client.Get , "v2")

           }
           "enumdefname" {
           
                return $Client.MakeRequest("types/enumdef/name/$($guid)", $false, $client.Get , "v2")

           }
           "relationshipdefname" {
           
                return $Client.MakeRequest("types/relationshipdef/name/$($guid)", $false, $client.Get , "v2")

           }
           "structdefname" {
           
                return $Client.MakeRequest("types/structdef/name/$($guid)", $false, $client.Get , "v2")

           }
           "typedefname" {
           
                return $Client.MakeRequest("types/typedef/name/$($guid)", $false, $client.Get , "v2")

           }
           "businessmetadatadefguid" {
           
                return $Client.MakeRequest("types/businessmetadatadef/guid/$($guid)", $false, $client.Get , "v2")

           }
           "classificationdefguid" {
           
                return $Client.MakeRequest("types/classificationdef/guid/$($guid)", $false, $client.Get , "v2")

           }
           "entitydefguid" {
           
                return $Client.MakeRequest("types/entitydef/guid/$($guid)", $false, $client.Get , "v2")

           }
           "enumdefguid" {
           
                return $Client.MakeRequest("types/enumdef/guid/$($guid)", $false, $client.Get , "v2")

           }
           "relationshipdefguid" {
           
                return $Client.MakeRequest("types/relationshipdef/guid/$($guid)", $false, $client.Get , "v2")

           }
           "structdefguid" {
           
                return $Client.MakeRequest("types/structdef/guid/$($guid)", $false, $client.Get , "v2")

           }
           "typedefguid" {
           
                return $Client.MakeRequest("types/typedef/guid/$($guid)", $false, $client.Get , "v2")

           }

        }

}
function Remove-TypeDefs {


    Param(

        [Parameter(
            Mandatory=$true
            , HelpMessage="The client to perform the request"
        )]
        [parameter(ParameterSetName = "typeNane")]
        [parameter(ParameterSetName = "typeDefs")]
        [Client]$Client,


        [Parameter(
            , HelpMessage="The client to perform the request"
        )]
        [parameter(ParameterSetName = "typeNane")]
        [String]$typeName,

        [Parameter(
            , HelpMessage="The client to perform the request"
        )]
        [parameter(ParameterSetName = "typeDefs")]
        [Object]$typeDefs
       )


         $FunctionType = $PSCmdlet.ParameterSetName

     Switch ($FunctionType)
        {
            "typeDefs" {
            
                return $Client.MakeRequest("types/typedefs", $typeDefs, $client.Delete , "v2")

            }
            "typeNane" {
            
                return $Client.MakeRequest("types/typedefs/name/$($typename)", $false, $client.Delete , "v2")
                

            }
        }

}
function Add-TypeDefs {


    Param(
    
    
        [Parameter(
            Mandatory=$true
            , HelpMessage="The client to perform the request"
        )]
        [parameter(ParameterSetName = "typeDefs")]
        [Client]$Client,

        [Parameter(
            , HelpMessage="The client to perform the request"
        )]
        [parameter(ParameterSetName = "typeDefs")]
        [Object]$typeDefs
        
    )


     $FunctionType = $PSCmdlet.ParameterSetName

     Switch ($FunctionType)
        {
            "typeDefs" {
            
                return $Client.MakeRequest("types/typedefs", $typeDefs, $client.Post , "v2")

            }
            
        }


    
}
function Set-TypeDefs {


    Param(
    
    
        [Parameter(
            Mandatory=$true
            , HelpMessage="The client to perform the request"
        )]
        [parameter(ParameterSetName = "typeDefs")]
        [Client]$Client,

        [Parameter(
            , HelpMessage="The client to perform the request"
        )]
        [parameter(ParameterSetName = "typeDefs")]
        [Object]$typeDefs
        
    )


     $FunctionType = $PSCmdlet.ParameterSetName

     Switch ($FunctionType)
        {
            "typeDefs" {
            
                return $Client.MakeRequest("types/typedefs", $typeDefs, $client.Put , "v2")

            }
            
        }

}

#endregion

#region Relationship API
function Get-Relationship{

    Param(

        [Parameter(
            Mandatory=$true
            , HelpMessage="The client to perform the request"
        )]
        [parameter(ParameterSetName = "GUID")]
        [Client]$Client,

        [Parameter(
             HelpMessage="The quilivant of GET /v2/entity/guid{guid}"
            , ParameterSetName="GUID"
            , Mandatory=$true
            )]
        [ValidatePattern('(\{|\()?[A-Za-z0-9]{4}([A-Za-z0-9]{4}\-?){4}[A-Za-z0-9]{12}(\}|\()?')]
        [String]$Guid

    )

     $FunctionType = $PSCmdlet.ParameterSetName

     Switch ($FunctionType){
            "GUID" {            
                return $Client.MakeRequest("relationship/guid/$($Guid)", $false, $client.Get , "v2")
            }
        }


}
function Remove-Relationship {


    Param(

        [Parameter(
            Mandatory=$true
            , HelpMessage="The client to perform the request"
        )]
        
        [parameter(ParameterSetName = "Guid")]
        [Client]$Client,

        [Parameter(
             HelpMessage="The quilivant of GET /v2/entity/guid{guid}"
            , ParameterSetName="GUID"
            , Mandatory=$true
            )]
        [ValidatePattern('(\{|\()?[A-Za-z0-9]{4}([A-Za-z0-9]{4}\-?){4}[A-Za-z0-9]{12}(\}|\()?')]
        [String]$Guid
       )


         $FunctionType = $PSCmdlet.ParameterSetName

     Switch ($FunctionType)
        {
            "GUID" {
            
                return $Client.MakeRequest("relationship/guid/$($Guid)", $false, $client.Delete , "v2")

            }
            
        }

}
function Set-Relationship {


    Param(
    
    
        [Parameter(
            Mandatory=$true
            , HelpMessage="The client to perform the request"
        )]
        [parameter(ParameterSetName = "relationship")]
        [Client]$Client,

        [Parameter(
            , HelpMessage="The client to perform the request"
        )]
        [parameter(ParameterSetName = "relationship")]
        [Object]$Relationship
        
    )


     $FunctionType = $PSCmdlet.ParameterSetName

     Switch ($FunctionType)
        {
            "relationship" {
            
                return $Client.MakeRequest("relationship", $Relationship, $client.Put , "v2")

            }
            
        }

}
function Add-Relationship {


    Param(
    
    
        [Parameter(
            Mandatory=$true
            , HelpMessage="The client to perform the request"
        )]
        [parameter(ParameterSetName = "relationship")]
        [Client]$Client,

        [Parameter(
            , HelpMessage="The client to perform the request"
        )]
        [parameter(ParameterSetName = "relationship")]
        [Object]$Relationship
        
    )


     $FunctionType = $PSCmdlet.ParameterSetName

     Switch ($FunctionType)
        {
            "relationship" {
            
                return $Client.MakeRequest("relationship", $Relationship, $client.Post , "v2")

            }
            
        }

}

#endregion

#region Lineage API

function Get-Lineage{

    Param(

        [Parameter(
            Mandatory=$true
            , HelpMessage="The client to perform the request"
        )]
        [parameter(ParameterSetName = "GUID")]
        [parameter(ParameterSetName = "typeName")]
        [Client]$Client,

        [Parameter(
             HelpMessage="The quilivant of GET /v2/entity/guid{guid}"
            , ParameterSetName="GUID"
            )]
        [ValidatePattern('(\{|\()?[A-Za-z0-9]{4}([A-Za-z0-9]{4}\-?){4}[A-Za-z0-9]{12}(\}|\()?')]
        [String]$Guid,

        [Parameter(
             HelpMessage="The quilivant of GET /v2/entity/guid{guid}"
            , ParameterSetName="typeName"
            )]
        [String]$TypeName

     )

     $FunctionType = $PSCmdlet.ParameterSetName

     Switch ($FunctionType)
        {
            "GUID" {
            
                return $Client.MakeRequest("lineage/$($Guid)", $false, $client.Get , "v2")

            }

            "typeName" {
            
                return $Client.MakeRequest("lineage/uniqueAttribut/type/$($typeName)", $false, $client.Get , "v2")

            }
            
        }


}

#endregion

#region Glossary API

function Get-Glossary{


    Param(


        [Parameter(
            Mandatory=$true
            , HelpMessage="The client to perform the request"
        )]
        [parameter(ParameterSetName = "All")]
        [parameter(ParameterSetName = "category")]
        [parameter(ParameterSetName = "term")]
        [parameter(ParameterSetName = "categories")]
        [parameter(ParameterSetName = "detailed")]
        [parameter(ParameterSetName = "terms")]
        [parameter(ParameterSetName = "importTemplate")]
        [parameter(ParameterSetName = "categoryRelated")]
        [parameter(ParameterSetName = "termsRelated")]
        [parameter(ParameterSetName = "termheaders")]
        [parameter(ParameterSetName = "categoriesheaders")]
        [parameter(ParameterSetName = "categoryRelated")]
        [parameter(ParameterSetName = "termsRelated")]
        [parameter(ParameterSetName = "categoryterms")]
        [Client]$Client,

        [Parameter(
             HelpMessage="The quilivant of GET /v2/entity/guid{guid}"
            , ParameterSetName="GUID"
            )]
        [ValidatePattern('(\{|\()?[A-Za-z0-9]{4}([A-Za-z0-9]{4}\-?){4}[A-Za-z0-9]{12}(\}|\()?')]
        [parameter(ParameterSetName = "category")]
        [parameter(ParameterSetName = "term")]
        [parameter(ParameterSetName = "categories")]
        [parameter(ParameterSetName = "detailed")]
        [parameter(ParameterSetName = "terms")]
        [parameter(ParameterSetName = "categoryRelated")]
        [parameter(ParameterSetName = "termsRelated")]
        [parameter(ParameterSetName = "termheaders")]
        [parameter(ParameterSetName = "categoriesheaders")]
        [parameter(ParameterSetName = "categoryRelated")]
        [parameter(ParameterSetName = "termsRelated")]
        [parameter(ParameterSetName = "categoryterms")]
        [String]$Guid,

        [parameter(ParameterSetName = "All")]
        [Switch]$All,

        [parameter(ParameterSetName = "category")]
        [parameter(ParameterSetName = "categoryRelated")]
        [parameter(ParameterSetName = "categoryterms")]
        [Switch]$category,

        [parameter(ParameterSetName = "term")]
        [parameter(ParameterSetName = "termsRelated")]
        [parameter(ParameterSetName = "termheaders")]
        [Switch]$term,

        [parameter(ParameterSetName = "categories")]
        [parameter(ParameterSetName = "categoriesheaders")]
        [Switch]$categories,

        [parameter(ParameterSetName = "detailed")]
        [Switch]$detailed,

        [parameter(ParameterSetName = "terms")]
        [parameter(ParameterSetName = "categoryterms")]
        [parameter(ParameterSetName = "assignedEntities")]
        [Switch]$terms,

        [parameter(ParameterSetName = "importTemplate")]
        [Switch]$importTemplate,

        [parameter(ParameterSetName = "categoryRelated")]
        [parameter(ParameterSetName = "termsRelated")]
        [Switch]$related,

        [parameter(ParameterSetName = "assignedEntities")]
        [Switch]$assignedEntities,

        [parameter(ParameterSetName = "termheaders")]
        [parameter(ParameterSetName = "categoriesheaders")]
        [Switch]$headers



    )


     $FunctionType = $PSCmdlet.ParameterSetName

     Switch ($FunctionType)
        {
            "All" {
            
                return $Client.MakeRequest("glossary", $false, $client.Get , "v2")

            }
            
            "GUID" {
            
                return $Client.MakeRequest("glossary/$($Guid)", $false, $client.Get , "v2")

            }

            "category" {
            
                return $Client.MakeRequest("glossary/category/$($Guid)", $false, $client.Get , "v2")

            }
            "term" {
            
                return $Client.MakeRequest("glossary/term/$($Guid)", $false, $client.Get , "v2")

            }
            "categories" {
            
                return $Client.MakeRequest("glossary/$($Guid)/categories", $false, $client.Get , "v2")

            }
            "detailed" {
            
                return $Client.MakeRequest("glossary/$($Guid)/detailed", $false, $client.Get , "v2")

            }
            "terms" {
            
                return $Client.MakeRequest("glossary/$($Guid)/terms", $false, $client.Get , "v2")

            }
            "importTemplate" {
            
                return $Client.MakeRequest("lineage/import/template", $false, $client.Get , "v2")

            }
             "categoryRelated"{
            
                return $Client.MakeRequest("glossary/category/$($Guid)/related", $false, $client.Get , "v2")

            }
            "categoryTerms"{
            
                return $Client.MakeRequest("glossary/category/$($Guid)/terms", $false, $client.Get , "v2")

            }
            "assignedEntities"{
            
                return $Client.MakeRequest("glossary/terms/$($Guid)/assignedEntities", $false, $client.Get , "v2")

            }

        "termsRelated"{
            
                return $Client.MakeRequest("glossary/terms/$($Guid)/related", $false, $client.Get , "v2")

            }
        "termheaders"{
            
                return $Client.MakeRequest("glossary/$($Guid)/terms/headers", $false, $client.Get , "v2")

            }
         "categoriesheaders"{
            
                return $Client.MakeRequest("glossary/$($Guid)/categories/headers", $false, $client.Get , "v2")

            }
            
        }

}
function Remove-Glossary{
    
    Param(
        [Parameter(
            Mandatory=$true
            , HelpMessage="The client to perform the request"
        )]
        [parameter(ParameterSetName = "glossary")]
        [parameter(ParameterSetName = "category")]
        [parameter(ParameterSetName = "term")]
        [parameter(ParameterSetName = "assignedEntities")]
        [Client]$Client,

        [Parameter(
             HelpMessage="The quilivant of GET /v2/entity/guid{guid}"
            , ParameterSetName="GUID"
            , Mandatory=$true
            )]
        [ValidatePattern('(\{|\()?[A-Za-z0-9]{4}([A-Za-z0-9]{4}\-?){4}[A-Za-z0-9]{12}(\}|\()?')]
        [parameter(ParameterSetName = "glossary")]
        [parameter(ParameterSetName = "category")]
        [parameter(ParameterSetName = "term")]
        [parameter(ParameterSetName = "assignedEntities")]
        [String]$Guid,

        [parameter(ParameterSetName = "category")]
        [Switch]$Category,

        [parameter(ParameterSetName = "assignedEntities")]
        [parameter(ParameterSetName = "term")]
        [Switch]$Term,

        [parameter(ParameterSetName = "assignedEntities")]
        [Switch]$AssignedEntities
        )

         $FunctionType = $PSCmdlet.ParameterSetName

         Switch ($FunctionType)
            {
                "glossary" {
            
                    return $Client.MakeRequest("glossary/$($Guid)", $false, $client.Delete , "v2")

                }
                "category" {
            
                    return $Client.MakeRequest("glossary/category/$($Guid)", $false, $client.Delete , "v2")

                }
                "term" {
            
                    return $Client.MakeRequest("glossary/term/$($Guid)", $false, $client.Delete , "v2")

                }
                "assignedEntities" {
            
                    return $Client.MakeRequest("glossary/terms/$($Guid)/assignedEntities", $false, $client.Delete , "v2")

                }
            }
}
function Add-Glossary{

Param(

        [Parameter(
            Mandatory=$true
            , HelpMessage="The client to perform the request"
        )]
        [parameter(ParameterSetName = "glossary")]
        [parameter(ParameterSetName = "category")]
        [parameter(ParameterSetName = "term")]
        [parameter(ParameterSetName = "assignedEntities")]
        [parameter(ParameterSetName = "bulkglossary")]
        [parameter(ParameterSetName = "bulkterms")]
        [parameter(ParameterSetName = "bulkcategories")]
        [Client]$Client,

        [parameter(ParameterSetName = "glossary")]
        [parameter(ParameterSetName = "bulkglossary")]
        [Object]$Glossaries,

        [parameter(ParameterSetName = "category")]
        [parameter(ParameterSetName = "bulkcategories")]
        [Object]$Categories,

        [parameter(ParameterSetName = "bulkglossary")]
        [parameter(ParameterSetName = "bulkterms")]
        [Switch]$Bulk,

        [parameter(ParameterSetName = "term")]
        [parameter(ParameterSetName = "bulkterms")]
        [Object]$Terms,

        [parameter(ParameterSetName = "assignedEntities")]
        [Object]$AssignedEntities,

        [ValidatePattern('(\{|\()?[A-Za-z0-9]{4}([A-Za-z0-9]{4}\-?){4}[A-Za-z0-9]{12}(\}|\()?')]
        [parameter(ParameterSetName = "assignedEntities")]
        [String]$guid

)

    $FunctionType = $PSCmdlet.ParameterSetName

    Switch ($FunctionType)
        {
            "glossary" {
                return $Client.MakeRequest("glossary", $Glossaries, $client.Post , "v2")
            }

            "category" {
                return $Client.MakeRequest("glossary/category", $Categories, $client.Post , "v2")
            }
            "bulkcategories" {
                return $Client.MakeRequest("glossary/categories", $Categories, $client.Post , "v2")
            }
        
            "term" {
                return $Client.MakeRequest("glossary/term", $Terms, $client.Post , "v2")
            }
        
            "assignedEntities" {
                return $Client.MakeRequest("glossary/terms/$($Guid)/assignedEntities", $AssignedEntities, $client.Post , "v2")
            }
        
            "bulkglossary" {
                return $Client.MakeRequest("glossary/import", $Glossaries, $client.Post , "v2")
            }
        
            "bulkterms" {
                return $Client.MakeRequest("glossary/terms", $Terms, $client.Post , "v2")
            }
        }

}
function Set-Glossary{

    Param(
    
        [Parameter(
            Mandatory=$true
            , HelpMessage="The client to perform the request"
        )]
        [parameter(ParameterSetName = "Glossary")]
        [parameter(ParameterSetName = "Category")]
        [parameter(ParameterSetName = "Term")]
        [parameter(ParameterSetName = "partialGlossary")]
        [parameter(ParameterSetName = "partialCategory")]
        [parameter(ParameterSetName = "partialTerm")]
        [parameter(ParameterSetName = "assignedEntities")]
        [Client]$Client,

        [ValidatePattern('(\{|\()?[A-Za-z0-9]{4}([A-Za-z0-9]{4}\-?){4}[A-Za-z0-9]{12}(\}|\()?')]
        [parameter(ParameterSetName = "Glossary")]
        [parameter(ParameterSetName = "Category")]
        [parameter(ParameterSetName = "Term")]
        [parameter(ParameterSetName = "partialGlossary")]
        [parameter(ParameterSetName = "partialCategory")]
        [parameter(ParameterSetName = "partialTerm")]
        [parameter(ParameterSetName = "assignedEntities")]
        [String]$Guid,

        [parameter(ParameterSetName = "partialGlossary")]
        [parameter(ParameterSetName = "Glossary")]
        [Object]$Glossary,

        [parameter(ParameterSetName = "partialCategory")]
        [parameter(ParameterSetName = "Category")]
        [Object]$category,

        [parameter(ParameterSetName = "partialTerm")]
        [parameter(ParameterSetName = "Term")]
        [Object]$term,

        [parameter(ParameterSetName = "partialGlossary")]
        [parameter(ParameterSetName = "partialCategory")]
        [parameter(ParameterSetName = "partialTerm")]
        [Switch]$partial,

        [parameter(ParameterSetName = "assignedEntities")]
        [Object]$assignedEntities
    
    )

    Switch ($FunctionType)
        {
            "Glossary" {
                return $Client.MakeRequest("glossary/$($Guid)", $Glossary, $client.Put , "v2")
            }

            "Category" {
                return $Client.MakeRequest("glossary/category/$($Guid)", $Category, $client.Put , "v2")
            }

            "Term" {
                return $Client.MakeRequest("glossary/term/$($Guid)", $Term , $client.Put , "v2")
            }

            "partialGlossary" {
                return $Client.MakeRequest("glossary/$($Guid)/partial", $Glossary , $client.Put , "v2")
            }

            "partialCategory" {
                return $Client.MakeRequest("glossary/category/$($Guid)/partial", $Category , $client.Put , "v2")
            }

            "partialTerm" {
                return $Client.MakeRequest("glossary/term/$($Guid)/partial", $Term , $client.Put , "v2")
            }

            "assignedEntities" {
                return $Client.MakeRequest("glossary/terms/$($Guid)/assignedEntities", $assignedEntities , $client.Put , "v2")
            }
        }
    
}

#endregion

#region Search API

function Search-Attribute {

    Param(
        [Parameter(Mandatory=$true)]
        [String] $AttributeName,

        [String] $AttributeValuePrefix,
        [int] $Limit,
        [int] $Offset,

        [Parameter(Mandatory=$true)]
        [String] $TypeName,
    
        [Parameter(Mandatory=$true)]
        [Client]$Client

    )

    $uri = "search/attribute?attrName=$($AttributeName)&typeName=$($TypeName)"

    if($AttributeValuePrefix){
        $uri += "&attriValuePrefix=$($AttributeValuePrefix)"
    }

    if($Limit){
        $uri += "&limit=$($Limit)"
    }

    if($Offset){
        $uri += "&offset=$($Offset)"
    }

    $client.MakeRequest("search/attribute?", $false, $client.Get , "v2")

}
function Search-Basic {

    Param(
    
    [String]$Classification,

    [bool]$ExcludeDeletedEntities=$false,

    [int]$Limit,

    [int]$Offset,

    [String]$Query,

    [String]$SortBy,

    [Switch]$Ascending,

    [Switch]$Descending,

    [Parameter(Mandatory=$true)]
    [String]$TypeName,

    [Parameter(Mandatory=$true)]
    [Client]$Client
    
    
    )

    $URI = "search/basic?typeName=$($TypeName)&query=$($Query)"

    if($Classification){
        $URI += "&classification=$($Classification)"
    }

    if($ExcludeDeletedEntities){
        $URI += "&excludedDeletedEntities=$($ExcludeDeletedEntities)"
    }

    
    if($Limit -AND $Limit -gt 0){
        $URI += "&limit=$($Limit)"
    }

    if($Offset -AND $Offset -gt 0){
        $URI += "&offset=$($Offset)"
    }

    if($SortBy){
        $URI += "&sortBy=$($SortBy)"
    }

    if($Descending){
        $URI += "&sortOrder=DESCENDING"
    }

    if($Ascending){
        $URI += "&sortOrder=ASCENDING"
    }


    $client.MakeRequest($URI, $false, $client.Get, "v2")

}
function Search-DSL {


    Param()

    Return "Placeholder, not implemented"

}
function Search-FullText {


    Param()

    Return "Placeholder, not implemented"

}
function Search-Quick {


    Param()

    Return "Placeholder, not implemented"

}
function Search-Relationship {


    Param()

    Return "Placeholder, not implemented"

}
function Search-Suggestion {


    Param()

    Return "Placeholder, not implemented"

}
function Search-Save{


    Param()

    Return "Placeholder, not implemented"

}

#endregion

Export-ModuleMember -Function New-PurviewClient, Get-Entity, Get-TypeDefs, Remove-TypeDefs, Add-TypeDefs, Set-TypeDefs, Get-Relationship, Remove-Relationship, Add-Relationship, Set-Relationship, Get-Glossary, Get-Lineage, Remove-Glossary, Add-Glossary, Set-Glossary, Add-Entity, Remove-Entity, Set-Entity

