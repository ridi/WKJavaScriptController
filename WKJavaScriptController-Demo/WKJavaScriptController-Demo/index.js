function submit() {
    var values = {};
    Array.prototype.slice.call(document.getElementsByTagName('input')).forEach(function(el) {
        if (el.type !== 'button' && el.type !== 'radio') {
            values[el.id] = el.value;
        }
    });
    if (isChecked('input_json')) {
        native.onSubmit(values);
    } else if (isChecked('input_literal')) {
        native.onSubmitWithFirstnameAndLastnameAndAddress1AndAddress2AndZipcodeAndPhonenumber(values['mail'], values['first_name'], values['last_name'], values['address_line_1'], values['address_line_2'], parseInt(values['zip_code']), values['phone_number']);
    }
}

function clearAll() {
    Array.prototype.slice.call(document.getElementsByTagName('input')).forEach(function(el) {
        if (el.type !== 'button' && el.type !== 'radio') {
            el.value = '';
        }
    });
}

function isChecked(id) {
    return document.getElementById(id).checked;
};
