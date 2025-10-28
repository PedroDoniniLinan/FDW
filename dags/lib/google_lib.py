import numpy as np
import os
import pandas as pd
import pickle
import re
import json
from dotenv.main import load_dotenv
from googleapiclient.discovery import build
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from google.auth.transport.requests import Request

def get_refresh_token():
    """Get refresh token for Google OAuth2 authentication.
    
    Returns:
        str: The refresh token obtained from running local OAuth2 flow
    """
    json_path = 'dags/lib/client_secret_619439483398-j65rb51rmvlrvkm6rlrtfim7ecu3qa38.apps.googleusercontent.com.json'
    SCOPES = ['https://www.googleapis.com/auth/spreadsheets', 'https://www.googleapis.com/auth/spreadsheets.readonly']

    flow = InstalledAppFlow.from_client_secrets_file(json_path, SCOPES)
    creds = flow.run_local_server(port=0)

    print("Your refresh token:", creds.refresh_token)
    return creds.refresh_token


def get_credentials():
    """Get credentials to connect to Google API.
    
    Returns:
        Credentials: Google OAuth2 credentials object using client credentials
        from the JSON file.
        
    Raises:
        Exception: If credentials file cannot be loaded or is invalid.
    """
    load_dotenv()
    try:
        creds = Credentials(
            None,
            refresh_token=os.getenv('REFRESH_TOKEN'),
            client_id=os.getenv('GCLOUD_CLIENT_ID'),
            client_secret=os.getenv('GCLOUD_CLIENT_SECRET'),
            token_uri="https://oauth2.googleapis.com/token"
        )
        return creds
    except Exception as e:
        raise Exception(f'Failed to load Google API credentials from JSON file: {str(e)}')


def create_service(api_name, creds):
    """Create Google API service client.
    
    Args:
        api_name (str): Name of the Google API service to create ('docs', 'drive', 
            'webmasters', 'sheets', or 'androidpublisher')
        creds (Credentials): Google OAuth2 credentials object
        
    Returns:
        Resource: Google API service client object
    """
    if api_name == 'docs':
        service = build(api_name, 'v1', credentials=creds)
    if api_name == 'drive':
        service = build(api_name, 'v3', credentials=creds)
    if api_name == 'webmasters':
        service = build(api_name, 'v3', credentials=creds)
    if api_name == 'sheets':
        service = build(api_name, 'v4', credentials=creds)
    if api_name == 'androidpublisher':
        service = build(api_name, 'v3', credentials=creds)
    return service


def read_spreadsheet(spreadsheet_id, range_name, debug=False):
    """Get data from a Google Sheets spreadsheet.
    
    Args:
        spreadsheet_id (str): ID of the Google Sheets spreadsheet
        range_name (str): Range to read in A1 notation (e.g. 'Sheet1!A1:D10')
        
    Returns:
        DataFrame: Pandas DataFrame containing the spreadsheet data with lowercase 
        column names
        
    Raises:
        Exception: If no data is found in the specified range
    """
    creds = get_credentials()
    
    if debug:
        print('Credentials: SUCCESS')

    service = create_service('sheets', creds)
    sheet = service.spreadsheets()

    if debug:
        print('Service: SUCCESS')

    result = sheet.values().get(
        spreadsheetId=spreadsheet_id,
        range=range_name).execute()
    
    if debug:
        print('Sheets read: SUCCESS')
    
    values = result.get('values', [])
    if not values:
        raise Exception('No data found')
    else:
        df = pd.DataFrame(values[1:], columns=values[0])
        df.columns = [c.lower().replace(' ', '_') for c in df.columns.tolist()]
        return df


def process_insert_range(range):
    """Process Google Sheets range string into components.
    
    Args:
        range (str): Range in A1 notation (e.g. 'Sheet1!A1:D10')
        
    Returns:
        tuple: Contains:
            - tab_name (str): Name of the sheet
            - first_range_col (str): Starting column letter
            - first_range_row (int): Starting row number  
            - last_range (str): Ending cell reference
    """
    re_match = re.match("(.*)!(.*):(.*)", range)

    tab_name = re_match[1]
    first_range_col = ''.join([x for x in re_match[2] if not x.isnumeric()])
    first_range_row = int(''.join([x for x in re_match[2] if x.isnumeric()]))
    last_range = re_match[3]
    return tab_name, first_range_col, first_range_row, last_range


def clear_spreadsheet(spreadsheet_id, range_name):
    """Clear data from a Google Sheets range.
    
    Args:
        spreadsheet_id (str): ID of the Google Sheets spreadsheet
        range_name (str): Range to clear in A1 notation
    """
    creds = get_credentials()
    service = create_service('sheets', creds)
    sheet = service.spreadsheets()
    body = {}
    sheet.values().clear(spreadsheetId=spreadsheet_id, range=range_name, body=body).execute()


def write_chunk(sheet, spreadsheet_id, tab_name, first_range_col, first_range_row, last_range, values):
    """Write a chunk of data to Google Sheets.
    
    Args:
        sheet: Google Sheets API service object
        spreadsheet_id (str): ID of the spreadsheet
        tab_name (str): Name of the sheet to write to
        first_range_col (str): Starting column letter
        first_range_row (int): Starting row number
        last_range (str): Ending cell reference
        values (list): 2D list of values to write
    """
    temp_range = f"'{tab_name}'!{first_range_col}{first_range_row}:{last_range}"
    body = {'values': values}
    sheet.values().append(
        spreadsheetId=spreadsheet_id,
        range=temp_range,
        valueInputOption='USER_ENTERED',
        # valueInputOption='RAW',
        body=body).execute()


def write_spreadsheet(spreadsheet_id, range_name, df, header=True):
    """Write DataFrame to Google Sheets, handling large datasets in chunks.
    
    Args:
        spreadsheet_id (str): ID of the Google Sheets spreadsheet
        range_name (str): Range to write to in A1 notation
        df (DataFrame): Pandas DataFrame containing data to write
        header (bool, optional): Whether to write column headers. Defaults to True.
    """
    creds = get_credentials()
    service = create_service('sheets', creds)
    sheet = service.spreadsheets()

    tab_name, first_range_col, first_range_row, last_range = process_insert_range(range_name) 

    if header:
        write_chunk(sheet, spreadsheet_id, tab_name, first_range_col, first_range_row, last_range, [df.columns.tolist()])
        first_range_row += 1

    chunks_number = np.ceil(len(df) / 10000)
    chunks = np.array_split(df, chunks_number) if chunks_number > 0 else []

    for chunk_data in chunks:
        write_chunk(sheet, spreadsheet_id, tab_name, first_range_col, first_range_row, last_range, chunk_data.values.tolist())
        first_range_row += len(chunk_data)


if __name__ == '__main__':
    print(1)
    get_refresh_token()
    # get_credentials()